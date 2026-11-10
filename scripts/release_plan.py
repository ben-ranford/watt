#!/usr/bin/env python3
"""Decide update embedding for an ad-hoc release.

Releases are ad-hoc signed and are not notarised. Apple Developer ID and
notary secrets are rejected so a leftover secret cannot change that.
Secret values are not printed. Partial update-url sets are errors.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_lib


APPLE_SECRET_NAMES = (
    'APPLE_CERTIFICATE_P12_BASE64',
    'APPLE_CERTIFICATE_PASSWORD',
    'APPLE_TEAM_ID',
    'APPLE_NOTARY_KEY_ID',
    'APPLE_NOTARY_ISSUER_ID',
    'APPLE_NOTARY_KEY_P8_BASE64',
)


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

    apple = [name for name in APPLE_SECRET_NAMES if _present(env, name)]
    if apple:
        errors.append(
            'Developer ID signing and notarization are not the release path. Remove these repository secrets: '
            + ', '.join(apple)
            + '.'
        )
    else:
        messages.append('Archiving with an ad-hoc signature. Releases are not Developer ID signed or notarised.')

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
        'code_signing': 'ad-hoc',
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
