"""Shared release-version and updater-manifest helpers.

CFBundleVersion stays a positive base-10 integer because UpdateConfiguration
rejects any other shape. Marketing version is semver. Released builds encode
that semver so the integer keeps increasing:

    MAJOR * 1_000_000 + MINOR * 1_000 + PATCH

Minor and patch must stay below 1000. The unreleased tree may keep
marketing 1.0.0 with build 1. A published release uses the encoded build.
Distribution preflight still rejects bundle identifiers that start with
dev.watt.verification.
"""

from __future__ import annotations

import base64
import hashlib
import json
import plistlib
import re
from pathlib import Path

VERSION_RE = re.compile(r'^([1-9][0-9]*|0)\.([0-9]+)\.([0-9]+)$')
TAG_RE = re.compile(r'^v([1-9][0-9]*|0)\.([0-9]+)\.([0-9]+)$')
IDENTITY_RE = re.compile(r'^[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z0-9-]+)+$')
BUILD_RE = re.compile(r'^[1-9][0-9]*$')
MINIMUM_RE = re.compile(r'^[1-9][0-9]*(?:\.(?:0|[1-9][0-9]*)){1,2}$')
ED25519_SPKI_PREFIX = bytes.fromhex('302a300506032b6570032100')
BASELINE_VERSION = '1.0.0'
BASELINE_BUILD = 1


class ReleaseError(ValueError):
    """Invalid release input that should stop the pipeline."""


def parse_version(value: str) -> tuple[int, int, int]:
    match = VERSION_RE.fullmatch(value)
    if match is None:
        raise ReleaseError('version must be MAJOR.MINOR.PATCH')
    major, minor, patch = (int(part) for part in match.groups())
    if minor > 999 or patch > 999:
        raise ReleaseError('minor and patch must stay below 1000 so CFBundleVersion stays monotonic')
    if major < 1:
        raise ReleaseError('marketing version must be at least 1.0.0')
    return major, minor, patch


def build_number(version: str) -> int:
    major, minor, patch = parse_version(version)
    value = major * 1_000_000 + minor * 1_000 + patch
    if value <= 0 or value >= 2**64:
        raise ReleaseError('encoded CFBundleVersion is outside UInt64')
    return value


def acceptable_builds(version: str, *, release: bool) -> set[int]:
    encoded = build_number(version)
    if release:
        return {encoded}
    if version == BASELINE_VERSION:
        return {BASELINE_BUILD, encoded}
    return {encoded}


def validate_tag(tag: str, version: str) -> None:
    if tag != 'v' + version or TAG_RE.fullmatch(tag) is None:
        raise ReleaseError('tag must be v' + version)


def validate_update_url(value: str, name: str) -> str:
    from urllib.parse import urlsplit

    if not isinstance(value, str) or value == '' or '$' in value or any(char.isspace() for char in value):
        raise ReleaseError(name + ' must be a configured HTTPS URL')
    url = urlsplit(value)
    if (
        url.scheme != 'https'
        or not url.hostname
        or url.username is not None
        or url.password is not None
        or url.fragment != ''
        or url.query != ''
        or (url.port is not None and url.port != 443)
    ):
        raise ReleaseError(name + ' must be https, without user, query, or fragment')
    return value


def validate_identity(value: str) -> str:
    if not isinstance(value, str) or IDENTITY_RE.fullmatch(value) is None or len(value) > 128:
        raise ReleaseError('invalid app identifier')
    return value


def validate_build(value: int | str) -> int:
    if isinstance(value, bool) or isinstance(value, str) and BUILD_RE.fullmatch(value) is None:
        raise ReleaseError('CFBundleVersion must be a positive integer without a leading zero')
    number = int(value)
    if number <= 0 or number >= 2**64:
        raise ReleaseError('CFBundleVersion is outside UInt64')
    return number


def validate_minimum(value: str) -> str:
    if MINIMUM_RE.fullmatch(value) is None:
        raise ReleaseError('minimumSystemVersion must be MAJOR.MINOR[.PATCH]')
    return value


def marketing_version(root: Path) -> str:
    text = (root / 'Config/Version.xcconfig').read_text()
    match = re.search(
        r'(?m)^MARKETING_VERSION = ([0-9]+\.[0-9]+\.[0-9]+) // x-release-please-version$',
        text,
    )
    if match is None:
        raise ReleaseError('Config/Version.xcconfig is missing the release-please marketing version')
    version = match.group(1)
    parse_version(version)
    version_file = (root / 'version.txt').read_text().strip()
    manifest = json.loads((root / '.release-please-manifest.json').read_text())
    if version_file != version or manifest.get('.') != version:
        raise ReleaseError('version.txt, release-please manifest, and MARKETING_VERSION disagree')
    return version


RELEASE_CONFIG_KEYS = frozenset({'appIdentifier', 'build', 'updateManifestURL', 'updateArtifactURL'})


def parse_release_config(data: object) -> dict[str, str | int]:
    if not isinstance(data, dict) or set(data) != RELEASE_CONFIG_KEYS:
        raise ReleaseError(
            'ReleaseIdentity.json must contain only appIdentifier, build, updateManifestURL, and updateArtifactURL'
        )
    identity = data['appIdentifier']
    manifest = data['updateManifestURL']
    artifact = data['updateArtifactURL']
    if not isinstance(identity, str) or not isinstance(manifest, str) or not isinstance(artifact, str):
        raise ReleaseError('release identity fields must be strings')
    return {
        'appIdentifier': validate_identity(identity),
        'build': validate_build(data['build']),
        'updateManifestURL': validate_update_url(manifest, 'updateManifestURL'),
        'updateArtifactURL': validate_update_url(artifact, 'updateArtifactURL'),
    }


def dump_release_config(config: dict[str, str | int]) -> str:
    normalized = parse_release_config(config)
    return json.dumps(normalized, sort_keys=True, separators=(',', ':')) + '\n'


def load_release_config(root: Path) -> dict[str, str | int]:
    return parse_release_config(json.loads((root / 'Resources/ReleaseIdentity.json').read_text()))


def load_identity(root: Path) -> tuple[str, int]:
    config = load_release_config(root)
    return str(config['appIdentifier']), int(config['build'])


def load_update_endpoints(root: Path) -> tuple[str, str]:
    config = load_release_config(root)
    return str(config['updateManifestURL']), str(config['updateArtifactURL'])


def project_build_numbers(text: str) -> list[str]:
    quoted = re.findall(r'CURRENT_PROJECT_VERSION" = "([0-9]+)"', text)
    unquoted = re.findall(r'CURRENT_PROJECT_VERSION = ([0-9]+);', text)
    return quoted + unquoted


def compiled_build(root: Path) -> int:
    swift = (root / 'HelperShared/HelperXPC.swift').read_text()
    swift_builds = re.findall(r'public static let build = "([0-9]+)"', swift)
    plist = (root / 'Resources/Helper/Info.plist').read_text()
    plist_builds = re.findall(r'<key>CFBundleVersion</key>\s*<string>([0-9]+)</string>', plist)
    project_builds = project_build_numbers((root / 'Watt.xcodeproj/project.pbxproj').read_text())
    if len(swift_builds) != 1 or len(plist_builds) != 1 or len(project_builds) < 1:
        raise ReleaseError('could not find a unique compiled build number')
    values = {validate_build(item) for item in [*swift_builds, *plist_builds, *project_builds]}
    if len(values) != 1:
        raise ReleaseError('compiled CFBundleVersion values disagree: ' + ', '.join(str(item) for item in sorted(values)))
    return values.pop()


def write_identity_build(root: Path, build: int) -> bool:
    """Point every compiled build number at `build`. Return whether anything changed."""
    config = load_release_config(root)
    identity = str(config['appIdentifier'])
    validate_build(build)
    changed = False
    config['build'] = build

    identity_path = root / 'Resources/ReleaseIdentity.json'
    identity_text = dump_release_config(config)
    changed |= _replace(identity_path, identity_text)

    swift_path = root / 'HelperShared/HelperXPC.swift'
    swift = swift_path.read_text()
    updated, count = re.subn(
        r'(public static let build = ")[0-9]+(")',
        rf'\g<1>{build}\g<2>',
        swift,
        count=1,
    )
    if count != 1:
        raise ReleaseError('HelperIdentity.build was not unique')
    changed |= _replace(swift_path, updated)

    plist_path = root / 'Resources/Helper/Info.plist'
    plist = plist_path.read_text()
    updated, count = re.subn(
        r'(<key>CFBundleVersion</key>\s*<string>)[0-9]+(</string>)',
        rf'\g<1>{build}\g<2>',
        plist,
        count=1,
    )
    if count != 1:
        raise ReleaseError('helper CFBundleVersion was not unique')
    changed |= _replace(plist_path, updated)

    project_path = root / 'Watt.xcodeproj/project.pbxproj'
    project = project_path.read_text()
    found = project_build_numbers(project)
    if not found:
        raise ReleaseError('project has no CURRENT_PROJECT_VERSION')
    updated, quoted_count = re.subn(
        r'(CURRENT_PROJECT_VERSION" = ")[0-9]+(")',
        rf'\g<1>{build}\g<2>',
        project,
    )
    updated, unquoted_count = re.subn(
        r'(CURRENT_PROJECT_VERSION = )[0-9]+(;)',
        rf'\g<1>{build}\g<2>',
        updated,
    )
    if quoted_count + unquoted_count != len(found):
        raise ReleaseError('refusing to rewrite an unexpected CURRENT_PROJECT_VERSION')
    changed |= _replace(project_path, updated)
    if compiled_build(root) != build or load_identity(root) != (identity, build):
        raise ReleaseError('build rewrite did not land in every compiled location')
    return changed


def _replace(path: Path, text: str) -> bool:
    current = path.read_text()
    if current == text:
        return False
    path.write_text(text)
    return True


# Signed release notes stay inside the manifest payload. 8192 bytes is the
# same cap the app enforces after the signature check. The prompt shows less.
NOTES_LIMIT = 8192
_NOTES_MARKER = '\n\n...'


def validate_notes(value: str) -> str:
    """Accept changelog text the app will keep after verifying the signature."""
    if not isinstance(value, str) or value.strip() == '':
        raise ReleaseError('release notes are empty')
    if len(value.encode('utf-8')) > NOTES_LIMIT:
        raise ReleaseError('release notes exceed 8192 bytes')
    for char in value:
        code = ord(char)
        if code == 127 or (code < 32 and char not in '\n\r\t'):
            raise ReleaseError('release notes contain a control character')
    return value


def limit_notes(text: str) -> str:
    """Keep a changelog section inside the signed-notes cap, on a line boundary."""
    encoded = text.encode('utf-8')
    if len(encoded) <= NOTES_LIMIT:
        return validate_notes(text)
    for char in text:
        code = ord(char)
        if code == 127 or (code < 32 and char not in '\n\r\t'):
            raise ReleaseError('release notes contain a control character')
    marker = _NOTES_MARKER.encode('utf-8')
    budget = NOTES_LIMIT - len(marker)
    trimmed = encoded[:budget].decode('utf-8', errors='ignore').encode('utf-8')
    newline = trimmed.rfind(b'\n')
    if newline >= budget // 2:
        trimmed = trimmed[:newline]
    return validate_notes(trimmed.decode('utf-8').rstrip() + _NOTES_MARKER)


def changelog_notes(text: str, version: str) -> str:
    """Body of the Release Please section for `version`, without the version heading."""
    parse_version(version)
    if not isinstance(text, str):
        raise ReleaseError('changelog must be text')
    normalized = text.replace('\r\n', '\n').replace('\r', '\n')
    match = re.search(
        r'^## \[' + re.escape(version) + r'\][^\n]*\n(.*?)(?=^## |\Z)',
        normalized,
        re.M | re.S,
    )
    if match is None:
        raise ReleaseError('changelog has no section for ' + version)
    body = match.group(1).strip('\n')
    if body.strip() == '':
        raise ReleaseError('changelog section for ' + version + ' is empty')
    return limit_notes(body)


def manifest_payload(identity: str, build: int, digest: bytes, minimum: str, notes: str | None = None) -> bytes:
    """Bytes matching JSONEncoder().encode(UpdateManifest) with default strategies.

    `notes` is omitted when absent so a manifest signed before that field still
    decodes. When present, the field is part of these exact signed bytes.
    """
    if len(digest) != 32:
        raise ReleaseError('sha256 must be 32 bytes')
    body: dict[str, str | int] = {
        'identity': validate_identity(identity),
        'build': validate_build(build),
        'sha256': base64.b64encode(digest).decode('ascii'),
        'minimumSystemVersion': validate_minimum(minimum),
    }
    if notes is not None:
        body['notes'] = validate_notes(notes)
    return json.dumps(body, separators=(',', ':'), ensure_ascii=True).encode('ascii')


def signed_update_document(payload: bytes, signature: bytes) -> bytes:
    """Bytes matching JSONEncoder().encode(SignedUpdate) with default strategies."""
    if len(signature) != 64:
        raise ReleaseError('Ed25519 signature must be 64 bytes')
    body = {
        'payload': base64.b64encode(payload).decode('ascii'),
        'signature': base64.b64encode(signature).decode('ascii'),
    }
    return json.dumps(body, separators=(',', ':'), ensure_ascii=True).encode('ascii')


def sha256_file(path: Path) -> bytes:
    hasher = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            hasher.update(chunk)
    return hasher.digest()


def raw_ed25519_public_key(der: bytes) -> bytes:
    if not der.startswith(ED25519_SPKI_PREFIX) or len(der) != len(ED25519_SPKI_PREFIX) + 32:
        raise ReleaseError('signing key is not an Ed25519 private key')
    return der[len(ED25519_SPKI_PREFIX):]


def decode_base64_env(value: str, path: Path) -> None:
    try:
        decoded = base64.b64decode(value, validate=True)
    except Exception as error:
        raise ReleaseError('secret is not valid base64') from error
    if not decoded:
        raise ReleaseError('secret decoded to empty')
    path.write_bytes(decoded)
    path.chmod(0o600)


def read_app_info(plist_path: Path) -> dict[str, str | int]:
    with plist_path.open('rb') as handle:
        info = plistlib.load(handle)
    identity = validate_identity(str(info.get('CFBundleIdentifier', '')))
    build = validate_build(str(info.get('CFBundleVersion', '')))
    marketing = str(info.get('CFBundleShortVersionString', ''))
    parse_version(marketing)
    minimum = validate_minimum(str(info.get('LSMinimumSystemVersion', '')))
    return {
        'identity': identity,
        'build': build,
        'marketing': marketing,
        'minimum': minimum,
    }


def parse_show_build_settings(text: str, target: str) -> dict[str, str]:
    """Parse one target from `xcodebuild -showBuildSettings` output."""
    sections = re.split(r'(?=Build settings for action )', text)
    found = None
    for section in sections:
        header = section.splitlines()[0] if section.strip() else ''
        if re.search(rf'\btarget {re.escape(target)}:\s*$', header):
            found = section
            break
    if found is None:
        raise ReleaseError('xcodebuild settings did not include target ' + target)
    settings: dict[str, str] = {}
    for line in found.splitlines()[1:]:
        if line.startswith('Build settings for action '):
            break
        match = re.match(r' {4}([A-Z][A-Z0-9_]*) = (.*)$', line)
        if match:
            settings[match.group(1)] = match.group(2)
    return settings

