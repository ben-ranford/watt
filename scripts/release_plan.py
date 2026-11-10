#!/usr/bin/env python3
"""Decide signing, notarization, and update embedding from the environment.

Secret values are not printed. Partial sets are errors. A completely absent
set is skipped and explained on stderr.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_lib


SIGNING_NAMES = ('APPLE_CERTIFICATE_P12_BASE64', 'APPLE_CERTIFICATE_PASSWORD', 'APPLE_TEAM_ID')
NOTARY_NAMES = ('APPLE_NOTARY_KEY_ID', 'APPLE_NOTARY_ISSUER_ID', 'APPLE_NOTARY_KEY_P8_BASE64')


def _present(env: dict[str, str], name: str) -> bool:
    return env.get(name, '').strip() != ''


def build_plan(env: dict[str, str], *, require_release: bool) -> dict[str, object]:
    errors: list[str] = []
    messages: list[str] = []
    version = env.get('RELEASE_VERSION', '').strip()
    tag = env.get('RELEASE_TAG', '').strip()
    if require_release or version or tag:
        try:
            release_lib.parse_version(version)
            release_lib.validate_tag(tag, version)
        except release_lib.ReleaseError as error:
            errors.append(str(error))

    signing_count = sum(_present(env, name) for name in SIGNING_NAMES)
    notary_count = sum(_present(env, name) for name in NOTARY_NAMES)
    code_signing = 'ad-hoc'
    team_id = ''
    if signing_count == 0:
        messages.append(
            'Developer ID signing secrets are absent. Archiving with the project ad-hoc identity and skipping notarization.'
        )
    elif signing_count != len(SIGNING_NAMES):
        errors.append(
            'Refusing to sign. Set all of APPLE_CERTIFICATE_P12_BASE64, APPLE_CERTIFICATE_PASSWORD, and APPLE_TEAM_ID, or leave all of them unset.'
        )
    else:
        team_id = env['APPLE_TEAM_ID'].strip()
        if release_lib.TEAM_RE.fullmatch(team_id) is None:
            errors.append('APPLE_TEAM_ID must be 10 uppercase letters or digits.')
        else:
            code_signing = 'developer-id'
            messages.append('Developer ID signing secrets are present. The archive will be signed.')

    notarize = False
    if notary_count == 0:
        messages.append('Notarization secrets are absent. Skipping notarization.')
    elif notary_count != len(NOTARY_NAMES):
        errors.append(
            'Refusing to notarize. Set all of APPLE_NOTARY_KEY_ID, APPLE_NOTARY_ISSUER_ID, and APPLE_NOTARY_KEY_P8_BASE64, or leave all of them unset.'
        )
    elif code_signing != 'developer-id':
        errors.append('Notarization secrets are set, but Developer ID signing secrets are not.')
    elif (
        release_lib.NOTARY_KEY_RE.fullmatch(env['APPLE_NOTARY_KEY_ID'].strip()) is None
        or release_lib.ISSUER_RE.fullmatch(env['APPLE_NOTARY_ISSUER_ID'].strip()) is None
    ):
        errors.append('Notarization key id or issuer id does not match the expected shape. The values were not logged.')
    else:
        notarize = True
        messages.append('Notarization secrets are present. The app and disk image will be submitted with notarytool.')

    key_present = _present(env, 'WATT_UPDATE_SIGNING_KEY')
    manifest_url = env.get('WATT_UPDATE_MANIFEST_URL', '').strip()
    artifact_url = env.get('WATT_UPDATE_ARTIFACT_URL', '').strip()
    url_count = (manifest_url != '') + (artifact_url != '')
    embed_update = False
    if url_count == 1:
        errors.append('Set both WATT_UPDATE_MANIFEST_URL and WATT_UPDATE_ARTIFACT_URL, or leave both unset.')
    elif url_count == 2 and not key_present:
        errors.append('Update URLs are set, but WATT_UPDATE_SIGNING_KEY is not. The app would not contain the matching public key.')
    elif url_count == 2:
        try:
            manifest_url = release_lib.validate_update_url(manifest_url, 'WATT_UPDATE_MANIFEST_URL')
            artifact_url = release_lib.validate_update_url(artifact_url, 'WATT_UPDATE_ARTIFACT_URL')
        except release_lib.ReleaseError as error:
            errors.append(str(error))
        else:
            embed_update = True
            messages.append('Update endpoints will be embedded. The updater refuses cross-host redirects, so these URLs must serve the bytes directly.')
    elif key_present:
        messages.append(
            'WATT_UPDATE_SIGNING_KEY is set without update URLs. The manifest will be signed only if distribution preflight passes, which also requires the URLs.'
        )
    else:
        messages.append('WATT_UPDATE_SIGNING_KEY is absent. Skipping the signed update manifest.')

    return {
        'version': version,
        'tag': tag,
        'code_signing': code_signing,
        'team_id': team_id,
        'notarize': notarize,
        'signing_key_present': key_present,
        'embed_update': embed_update,
        'manifest_url': manifest_url if embed_update else '',
        'artifact_url': artifact_url if embed_update else '',
        'messages': messages,
        'errors': errors,
    }


def main() -> None:
    plan = build_plan(dict(os.environ), require_release=True)
    for message in plan['messages']:
        print(message, file=sys.stderr)
    for error in plan['errors']:
        print('BLOCKED: ' + str(error), file=sys.stderr)
    json.dump(plan, sys.stdout)
    sys.stdout.write('\n')
    if plan['errors']:
        sys.exit(1)


if __name__ == '__main__':
    main()
