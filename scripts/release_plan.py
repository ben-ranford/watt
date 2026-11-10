#!/usr/bin/env python3
"""Decide update embedding for an ad-hoc release.

Releases are ad-hoc signed and are not notarised. Apple Developer ID and
notary secrets are rejected so a leftover secret cannot change that.
Update URLs are read from Resources/ReleaseIdentity.json, not from secrets.
The signing key is optional: without it the archive still builds, and
distribution preflight fails because the public key is absent.
Secret values are not printed.
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


def build_plan(
    env: dict[str, str],
    *,
    require_release: bool,
    root: Path | None = None,
    endpoints: tuple[str, str] | None = None,
) -> dict[str, object]:
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

    for name in ('WATT_UPDATE_MANIFEST_URL', 'WATT_UPDATE_ARTIFACT_URL'):
        if _present(env, name):
            errors.append(
                name + ' is not a release secret. Delete it. The update URLs are committed in Resources/ReleaseIdentity.json.'
            )

    key_present = _present(env, 'WATT_UPDATE_SIGNING_KEY')
    manifest_url = ''
    artifact_url = ''
    source = root or Path(__file__).resolve().parents[1]
    try:
        if endpoints is None:
            manifest_url, artifact_url = release_lib.load_update_endpoints(source)
        else:
            manifest_url = release_lib.validate_update_url(endpoints[0], 'updateManifestURL')
            artifact_url = release_lib.validate_update_url(endpoints[1], 'updateArtifactURL')
    except release_lib.ReleaseError as error:
        errors.append(str(error))
        manifest_url, artifact_url = '', ''
    embed_update = manifest_url != '' and artifact_url != ''
    if embed_update:
        messages.append(
            'Update endpoints from Resources/ReleaseIdentity.json will be compiled into the app as WATT_UPDATE_MANIFEST_URL and WATT_UPDATE_ARTIFACT_URL. The updater refuses cross-host redirects, so these URLs must serve the bytes directly.'
        )
    if key_present:
        messages.append('WATT_UPDATE_PUBLIC_KEY will be derived from WATT_UPDATE_SIGNING_KEY and compiled into the app.')
    else:
        messages.append(
            'WATT_UPDATE_SIGNING_KEY is absent. The archive still builds. Distribution preflight fails without the public key, and no manifest is published.'
        )

    return {
        'version': version,
        'tag': tag,
        'code_signing': 'ad-hoc',
        'signing_key_present': key_present,
        'embed_update': embed_update,
        'embed_public_key': key_present and embed_update,
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
