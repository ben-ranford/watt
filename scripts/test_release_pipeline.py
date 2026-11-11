#!/usr/bin/env python3
"""Checks for the release pipeline that can run without Xcode."""

from __future__ import annotations

import base64
import hashlib
import json
import re
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import release_lib
import release_plan
import release_readiness
import render_homebrew_cask
import rollout_manifest


def run(arguments: list[str], *, env: dict[str, str] | None = None, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    merged = os.environ.copy()
    if env:
        merged.update(env)
    return subprocess.run(arguments, cwd=cwd or ROOT, env=merged, text=True, capture_output=True)


class VersionTests(unittest.TestCase):
    def test_encoded_build_is_monotonic(self) -> None:
        self.assertEqual(release_lib.build_number('1.0.0'), 1_000_000)
        self.assertEqual(release_lib.build_number('1.2.3'), 1_002_003)
        self.assertLess(release_lib.build_number('1.0.999'), release_lib.build_number('1.1.0'))
        self.assertLess(release_lib.build_number('1.999.999'), release_lib.build_number('2.0.0'))
        with self.assertRaises(release_lib.ReleaseError):
            release_lib.build_number('1.1000.0')
        with self.assertRaises(release_lib.ReleaseError):
            release_lib.build_number('0.1.0')

    def test_repository_baseline_matches_identity(self) -> None:
        version = release_lib.marketing_version(ROOT)
        encoded = release_lib.build_number(version)
        identity, build = release_lib.load_identity(ROOT)
        self.assertEqual(identity, 'io.github.ben-ranford.watt')
        self.assertEqual(
            release_lib.load_update_endpoints(ROOT),
            (
                'https://ben-ranford.github.io/watt/updates/manifest.json',
                'https://ben-ranford.github.io/watt/updates/Watt.tar',
            ),
        )
        # The tree is either the unreleased 1.0.0 / build 1 baseline or a
        # release whose build is the encoded marketing version.
        self.assertIn(build, {1, encoded} if version == '1.0.0' else {encoded})
        self.assertEqual(release_lib.compiled_build(ROOT), build)
        self.assertIn(build, release_lib.acceptable_builds(version, release=False))
        self.assertEqual(release_lib.acceptable_builds(version, release=True), {encoded})
        check = run([sys.executable, 'scripts/sync-release-version.py'])
        self.assertEqual(check.returncode, 0, check.stderr)
        self.assertIn('SKIP: configure-release-identity.py', check.stdout)
        release = run([sys.executable, 'scripts/sync-release-version.py', '--release'])
        if build == encoded:
            self.assertEqual(release.returncode, 0, release.stderr)
        else:
            self.assertEqual(release.returncode, 1, release.stdout)
            self.assertIn('BLOCKED', release.stderr)

    def test_write_updates_every_compiled_build_without_changing_identity(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for relative in (
                'Config/Version.xcconfig',
                'version.txt',
                '.release-please-manifest.json',
                'Resources/ReleaseIdentity.json',
                'Resources/Helper/Info.plist',
                'HelperShared/HelperXPC.swift',
                'Watt.xcodeproj/project.pbxproj',
            ):
                destination = root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / relative, destination)
            version = '1.2.3'
            (root / 'version.txt').write_text(version + '\n')
            (root / '.release-please-manifest.json').write_text(json.dumps({'.': version}) + '\n')
            xcconfig = re.sub(
                r'MARKETING_VERSION = \d+\.\d+\.\d+',
                f'MARKETING_VERSION = {version}',
                (root / 'Config/Version.xcconfig').read_text(),
                count=1,
            )
            (root / 'Config/Version.xcconfig').write_text(xcconfig)
            result = run([sys.executable, str(ROOT / 'scripts/sync-release-version.py'), '--write', '--root', str(root)])
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(release_lib.load_identity(root), ('io.github.ben-ranford.watt', 1_002_003))
            self.assertEqual(
                release_lib.load_update_endpoints(root),
                (
                    'https://ben-ranford.github.io/watt/updates/manifest.json',
                    'https://ben-ranford.github.io/watt/updates/Watt.tar',
                ),
            )
            self.assertEqual(release_lib.compiled_build(root), 1_002_003)
            self.assertIn('baseConfigurationReference = E7A4C91B2D0F4A6C8B3E1D50', (root / 'Watt.xcodeproj/project.pbxproj').read_text())
            again = run([sys.executable, str(ROOT / 'scripts/sync-release-version.py'), '--release', '--root', str(root)])
            self.assertEqual(again.returncode, 0, again.stderr)


class ManifestTests(unittest.TestCase):
    def test_payload_matches_swift_json_encoder_layout(self) -> None:
        digest = hashlib.sha256(b'watt').digest()
        payload = release_lib.manifest_payload('dev.watt.example', 1_002_003, digest, '13.0')
        expected = (
            b'{"identity":"dev.watt.example","build":1002003,"sha256":"'
            + base64.b64encode(digest)
            + b'","minimumSystemVersion":"13.0"}'
        )
        self.assertEqual(payload, expected)
        signature = b'\x11' * 64
        document = release_lib.signed_update_document(payload, signature)
        self.assertTrue(document.startswith(b'{"payload":"'))
        decoded = json.loads(document)
        self.assertEqual(base64.b64decode(decoded['payload']), payload)
        self.assertEqual(len(base64.b64decode(decoded['signature'])), 64)

    def test_sign_and_verify_with_openssl(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            pem = directory / 'key.pem'
            archive = directory / 'Watt-1.2.3.tar'
            output = directory / 'manifest.json'
            public_out = directory / 'public.txt'
            archive.write_bytes(b'ustar-bytes')
            subprocess.run(['openssl', 'genpkey', '-algorithm', 'ED25519', '-out', str(pem)], check=True, capture_output=True)
            encoded = base64.b64encode(pem.read_bytes()).decode('ascii')
            result = run(
                [sys.executable, 'scripts/sign-update-manifest.py', '--archive', str(archive), '--identity', 'dev.watt.example',
                 '--build', '1002003', '--minimum-system-version', '13.0', '--output', str(output), '--public-key-out', str(public_out)],
                env={'WATT_UPDATE_SIGNING_KEY': encoded},
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn('PRIVATE', result.stdout + result.stderr)
            document = json.loads(output.read_text())
            payload = base64.b64decode(document['payload'])
            signature = base64.b64decode(document['signature'])
            self.assertEqual(len(signature), 64)
            payload_path = directory / 'payload.json'
            signature_path = directory / 'sig.bin'
            public_pem = directory / 'public.pem'
            payload_path.write_bytes(payload)
            signature_path.write_bytes(signature)
            subprocess.run(['openssl', 'pkey', '-in', str(pem), '-pubout', '-out', str(public_pem)], check=True, capture_output=True)
            verify = subprocess.run(
                ['openssl', 'pkeyutl', '-verify', '-pubin', '-inkey', str(public_pem), '-rawin', '-in', str(payload_path), '-sigfile', str(signature_path)],
                capture_output=True,
            )
            self.assertEqual(verify.returncode, 0, verify.stderr)
            der = subprocess.run(['openssl', 'pkey', '-in', str(pem), '-pubout', '-outform', 'DER'], check=True, capture_output=True).stdout
            self.assertEqual(public_out.read_text().strip(), base64.b64encode(release_lib.raw_ed25519_public_key(der)).decode('ascii'))
            self.assertNotIn('notes', json.loads(payload))

    def test_notes_are_inside_the_signed_payload(self) -> None:
        digest = hashlib.sha256(b'watt').digest()
        notes = 'See "updates" at https://example.test/notes\n\n* one'
        payload = release_lib.manifest_payload('dev.watt.example', 1_002_003, digest, '13.0', notes)
        self.assertTrue(payload.endswith(b'}'))
        self.assertIn(b'"notes":', payload)
        self.assertEqual(json.loads(payload)['notes'], notes)
        self.assertEqual(
            release_lib.manifest_payload('dev.watt.example', 1_002_003, digest, '13.0'),
            payload[: payload.index(b',"notes":')] + b'}',
        )
        with self.assertRaises(release_lib.ReleaseError):
            release_lib.manifest_payload('dev.watt.example', 1_002_003, digest, '13.0', ' ')
        with self.assertRaises(release_lib.ReleaseError):
            release_lib.manifest_payload('dev.watt.example', 1_002_003, digest, '13.0', 'bad\x01')
        with self.assertRaises(release_lib.ReleaseError):
            release_lib.manifest_payload('dev.watt.example', 1_002_003, digest, '13.0', 'a' * (release_lib.NOTES_LIMIT + 1))

    def test_changelog_section_is_bounded_and_version_scoped(self) -> None:
        text = (ROOT / 'CHANGELOG.md').read_text(encoding='utf-8')
        current = release_lib.changelog_notes(text, '1.0.1')
        self.assertIn('compile update endpoints', current)
        self.assertNotIn('initial public release', current)
        self.assertNotIn('## [1.0.0]', current)
        initial = release_lib.changelog_notes(text, '1.0.0')
        self.assertIn('initial public release', initial)
        self.assertNotIn('compile update endpoints', initial)
        self.assertNotIn('## Changelog', initial)
        self.assertLessEqual(len(current.encode('utf-8')), release_lib.NOTES_LIMIT)
        with self.assertRaises(release_lib.ReleaseError):
            release_lib.changelog_notes(text, '9.9.9')
        with self.assertRaises(release_lib.ReleaseError):
            release_lib.changelog_notes('## [1.2.3](https://example.test) (2026-11-10)\n\n\n', '1.2.3')
        with self.assertRaises(release_lib.ReleaseError):
            release_lib.changelog_notes('## [1.2.3](https://example.test)\n\nbad\x01\n', '1.2.3')
        long_section = '## [1.2.3](https://example.test)\n\n' + ('* line\n' * 3000)
        limited = release_lib.changelog_notes(long_section, '1.2.3')
        self.assertLessEqual(len(limited.encode('utf-8')), release_lib.NOTES_LIMIT)
        self.assertTrue(limited.endswith('\n\n...'))
        self.assertIn('* line', limited)

    def test_signed_notes_fail_verification_when_changed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            pem = directory / 'key.pem'
            archive = directory / 'Watt-1.2.3.tar'
            output = directory / 'manifest.json'
            changelog = directory / 'CHANGELOG.md'
            archive.write_bytes(b'ustar-bytes')
            changelog.write_text(
                '## [1.2.3](https://example.test/compare/v1.2.2...v1.2.3) (2026-11-10)\n\n'
                '### Fixes\n\n* steadier numbers\n\n'
                '## [1.2.2](https://example.test/compare) (2026-11-01)\n\n### Fixes\n\n* older\n',
                encoding='utf-8',
            )
            subprocess.run(['openssl', 'genpkey', '-algorithm', 'ED25519', '-out', str(pem)], check=True, capture_output=True)
            result = run(
                [sys.executable, 'scripts/sign-update-manifest.py', '--archive', str(archive), '--identity', 'dev.watt.example',
                 '--build', '1002003', '--minimum-system-version', '13.0', '--changelog', str(changelog),
                 '--marketing-version', '1.2.3', '--output', str(output)],
                env={'WATT_UPDATE_SIGNING_KEY': base64.b64encode(pem.read_bytes()).decode('ascii')},
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            document = json.loads(output.read_text())
            payload = base64.b64decode(document['payload'])
            self.assertEqual(json.loads(payload)['notes'], '### Fixes\n\n* steadier numbers')
            self.assertNotIn('older', json.loads(payload)['notes'])
            payload_path = directory / 'payload.json'
            signature_path = directory / 'sig.bin'
            public_pem = directory / 'public.pem'
            payload_path.write_bytes(payload)
            signature_path.write_bytes(base64.b64decode(document['signature']))
            subprocess.run(['openssl', 'pkey', '-in', str(pem), '-pubout', '-out', str(public_pem)], check=True, capture_output=True)
            verified = subprocess.run(
                ['openssl', 'pkeyutl', '-verify', '-pubin', '-inkey', str(public_pem), '-rawin', '-in', str(payload_path), '-sigfile', str(signature_path)],
                capture_output=True,
            )
            self.assertEqual(verified.returncode, 0, verified.stderr)
            payload_path.write_bytes(payload.replace(b'steadier numbers', b'steadier NUMBER'))
            tampered = subprocess.run(
                ['openssl', 'pkeyutl', '-verify', '-pubin', '-inkey', str(public_pem), '-rawin', '-in', str(payload_path), '-sigfile', str(signature_path)],
                capture_output=True,
            )
            self.assertNotEqual(tampered.returncode, 0)
            missing = run(
                [sys.executable, 'scripts/sign-update-manifest.py', '--archive', str(archive), '--identity', 'dev.watt.example',
                 '--build', '1002003', '--minimum-system-version', '13.0', '--changelog', str(changelog),
                 '--marketing-version', '9.9.9', '--output', str(directory / 'missing.json')],
                env={'WATT_UPDATE_SIGNING_KEY': base64.b64encode(pem.read_bytes()).decode('ascii')},
            )
            self.assertEqual(missing.returncode, 1)
            self.assertIn('BLOCKED', missing.stderr)
            self.assertFalse((directory / 'missing.json').exists())

    def test_non_ed25519_key_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            pem = directory / 'ec.pem'
            archive = directory / 'archive.tar'
            archive.write_bytes(b'bytes')
            subprocess.run(
                ['openssl', 'genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:P-256', '-out', str(pem)],
                check=True,
                capture_output=True,
            )
            result = run(
                [sys.executable, 'scripts/sign-update-manifest.py', '--public-key-out', str(directory / 'public.txt')],
                env={'WATT_UPDATE_SIGNING_KEY': base64.b64encode(pem.read_bytes()).decode('ascii')},
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn('BLOCKED', result.stderr)
            self.assertNotIn(pem.read_text(), result.stderr)


class PlanTests(unittest.TestCase):
    def test_absent_secrets_archive_ad_hoc_without_a_manifest(self) -> None:
        plan = release_plan.build_plan({'RELEASE_VERSION': '1.2.3', 'RELEASE_TAG': 'v1.2.3'}, require_release=True)
        self.assertEqual(plan['errors'], [])
        self.assertEqual(plan['code_signing'], 'ad-hoc')
        self.assertNotIn('notarize', plan)
        self.assertFalse(plan['signing_key_present'])
        self.assertFalse(plan['embed_public_key'])
        self.assertTrue(plan['embed_update'])
        self.assertEqual(plan['manifest_url'], 'https://ben-ranford.github.io/watt/updates/manifest.json')
        self.assertEqual(plan['artifact_url'], 'https://ben-ranford.github.io/watt/updates/Watt.tar')
        self.assertTrue(any('ad-hoc' in message for message in plan['messages']))
        self.assertTrue(any('preflight' in message for message in plan['messages']))
        self.assertFalse(any('fallback' in message.lower() for message in plan['messages']))

    def test_apple_signing_secrets_are_rejected(self) -> None:
        partial = release_plan.build_plan(
            {'RELEASE_VERSION': '1.2.3', 'RELEASE_TAG': 'v1.2.3', 'APPLE_TEAM_ID': 'ABCDE12345'},
            require_release=True,
        )
        self.assertTrue(partial['errors'])
        encoded = json.dumps(partial['errors'])
        self.assertNotIn('ABCDE12345', encoded)
        self.assertIn('APPLE_TEAM_ID', encoded)
        self.assertEqual(partial['code_signing'], 'ad-hoc')

    def test_partial_and_invalid_secrets_fail_closed(self) -> None:
        leftover = release_plan.build_plan(
            {
                'RELEASE_VERSION': '1.2.3',
                'RELEASE_TAG': 'v1.2.3',
                'WATT_UPDATE_MANIFEST_URL': 'https://updates.example/manifest.json',
                'WATT_UPDATE_ARTIFACT_URL': 'https://github.com/ben-ranford/watt/releases/download/v1.2.3/Watt.tar?raw=1',
                'WATT_UPDATE_SIGNING_KEY': 'cGVt',
            },
            require_release=True,
        )
        self.assertTrue(any('not a release secret' in error for error in leftover['errors']))
        self.assertNotIn('cGVt', json.dumps(leftover))
        invalid = release_plan.build_plan(
            {'RELEASE_VERSION': '1.2.3', 'RELEASE_TAG': 'v1.2.3'},
            require_release=True,
            endpoints=(
                'https://github.com/ben-ranford/watt/releases/download/v1.2.3/Watt.tar?raw=1',
                'https://ben-ranford.github.io/watt/updates/Watt.tar',
            ),
        )
        self.assertTrue(any('query' in error or 'https' in error for error in invalid['errors']))
        mismatch = release_plan.build_plan({'RELEASE_VERSION': '1.2.3', 'RELEASE_TAG': 'v9.9.9'}, require_release=True)
        self.assertTrue(mismatch['errors'])

    def test_complete_update_plan_omits_secret_material(self) -> None:
        plan = release_plan.build_plan(
            {
                'RELEASE_VERSION': '1.2.3',
                'RELEASE_TAG': 'v1.2.3',
                'WATT_UPDATE_SIGNING_KEY': 'cGVt',
            },
            require_release=True,
        )
        self.assertEqual(plan['errors'], [])
        self.assertEqual(plan['code_signing'], 'ad-hoc')
        self.assertTrue(plan['embed_update'])
        self.assertTrue(plan['embed_public_key'])
        self.assertEqual(plan['manifest_url'], 'https://ben-ranford.github.io/watt/updates/manifest.json')
        self.assertEqual(plan['artifact_url'], 'https://ben-ranford.github.io/watt/updates/Watt.tar')
        encoded = json.dumps(plan)
        self.assertNotIn('cGVt', encoded)
        apple = release_plan.build_plan(
            {
                'RELEASE_VERSION': '1.2.3',
                'RELEASE_TAG': 'v1.2.3',
                'APPLE_CERTIFICATE_P12_BASE64': 'Y2VydA==',
                'APPLE_CERTIFICATE_PASSWORD': 'secret-password',
                'APPLE_NOTARY_KEY_P8_BASE64': 'cDhrZXk=',
                'WATT_UPDATE_SIGNING_KEY': 'cGVt',
            },
            require_release=True,
        )
        self.assertTrue(apple['errors'])
        rejected = json.dumps(apple)
        self.assertNotIn('secret-password', rejected)
        self.assertNotIn('Y2VydA==', rejected)
        self.assertNotIn('cDhrZXk=', rejected)


class ProjectTests(unittest.TestCase):
    def test_version_xcconfig_is_the_project_base_configuration(self) -> None:
        project = (ROOT / 'Watt.xcodeproj/project.pbxproj').read_text()
        self.assertEqual(project.count('baseConfigurationReference = E7A4C91B2D0F4A6C8B3E1D50'), 3)
        self.assertIn('path = Config/Version.xcconfig', project)
        self.assertRegex(
            (ROOT / 'Config/Version.xcconfig').read_text(),
            r'MARKETING_VERSION = \d+\.\d+\.\d+ // x-release-please-version',
        )

    def test_app_info_plist_expands_custom_keys_before_signing(self) -> None:
        import plistlib
        app = plistlib.loads((ROOT / 'Resources/App/Info.plist').read_bytes())
        helper = plistlib.loads((ROOT / 'Resources/Helper/Info.plist').read_bytes())
        self.assertEqual(app['WATTHelperTrustMode'], '$(WATT_HELPER_TRUST_MODE)')
        self.assertEqual(helper['WATTHelperTrustMode'], '$(WATT_HELPER_TRUST_MODE)')
        self.assertEqual(app['WATTSigningTeam'], '$(DEVELOPMENT_TEAM)')
        self.assertEqual(helper['WATTSigningTeam'], '$(DEVELOPMENT_TEAM)')
        self.assertEqual(app['WATTUpdateManifestURL'], '$(WATT_UPDATE_MANIFEST_URL)')
        self.assertEqual(app['WATTUpdateArtifactURL'], '$(WATT_UPDATE_ARTIFACT_URL)')
        self.assertEqual(app['WATTUpdatePublicKey'], '$(WATT_UPDATE_PUBLIC_KEY)')
        project = (ROOT / 'Watt.xcodeproj/project.pbxproj').read_text()
        self.assertNotIn('INFOPLIST_KEY_WATT', project)
        self.assertEqual(project.count('"INFOPLIST_FILE" = "Resources/App/Info.plist"'), 3)
        self.assertEqual(project.count('"WATT_UPDATE_MANIFEST_URL" = ""'), 3)
        self.assertEqual(project.count('"WATT_UPDATE_ARTIFACT_URL" = ""'), 3)
        self.assertEqual(project.count('"WATT_UPDATE_PUBLIC_KEY" = ""'), 3)
        self.assertEqual(project.count('"WATT_HELPER_TRUST_MODE" = "protected-installation"'), 4)
        self.assertEqual(project.count('"WATT_HELPER_TRUST_MODE" = "certificate"'), 2)

    def test_show_build_settings_parser_selects_watt(self) -> None:
        text = """Build settings for action build and target WattHelper:
    MARKETING_VERSION = 9.9.9
    CURRENT_PROJECT_VERSION = 9
Build settings for action build and target Watt:
    MARKETING_VERSION = 1.2.3
    CURRENT_PROJECT_VERSION = 1002003
    PRODUCT_BUNDLE_IDENTIFIER = dev.watt.example
    ENABLE_TESTABILITY = NO
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO
Build settings for action build and target WattTests:
    MARKETING_VERSION = 1.2.3
    CURRENT_PROJECT_VERSION = 4
"""
        settings = release_lib.parse_show_build_settings(text, 'Watt')
        self.assertEqual(settings['MARKETING_VERSION'], '1.2.3')
        self.assertEqual(settings['CURRENT_PROJECT_VERSION'], '1002003')
        with tempfile.TemporaryDirectory() as temporary:
            log = Path(temporary) / 'settings.txt'
            log.write_text(text)
            result = run([
                sys.executable, 'scripts/check_xcode_settings.py', str(log),
                '--marketing', '1.2.3', '--build', '1002003',
            ])
            self.assertEqual(result.returncode, 0, result.stderr)
            mismatch = run([
                sys.executable, 'scripts/check_xcode_settings.py', str(log),
                '--marketing', '1.2.3', '--build', '1',
            ])
            self.assertEqual(mismatch.returncode, 1)
            debuggable = text.replace('ENABLE_TESTABILITY = NO', 'ENABLE_TESTABILITY = YES')
            log.write_text(debuggable)
            injected = run([
                sys.executable, 'scripts/check_xcode_settings.py', str(log),
                '--marketing', '1.2.3', '--build', '1002003',
            ])
            self.assertEqual(injected.returncode, 1)
            self.assertIn('get-task-allow', injected.stderr)

    def test_workflow_does_not_read_apple_signing_secrets(self) -> None:
        text = (ROOT / '.github/workflows/release.yml').read_text()
        for name in (
            'APPLE_CERTIFICATE_P12_BASE64',
            'APPLE_CERTIFICATE_PASSWORD',
            'APPLE_TEAM_ID',
            'APPLE_NOTARY_KEY_ID',
            'APPLE_NOTARY_ISSUER_ID',
            'APPLE_NOTARY_KEY_P8_BASE64',
            'notarytool',
            'developer-id',
        ):
            self.assertNotIn(name, text)
        self.assertIn('HOMEBREW_TAP_DEPLOY_KEY', text)
        self.assertNotIn('HOMEBREW_TAP_TOKEN', text)
        self.assertIn('WATT_UPDATE_SIGNING_KEY', text)
        self.assertNotIn('WATT_UPDATE_MANIFEST_URL', text)
        self.assertNotIn('WATT_UPDATE_ARTIFACT_URL', text)

    def test_update_urls_match_the_updater_rules(self) -> None:
        self.assertEqual(
            release_lib.validate_update_url('https://updates.example/manifest.json', 'WATT_UPDATE_MANIFEST_URL'),
            'https://updates.example/manifest.json',
        )
        for value in (
            'http://updates.example/manifest.json',
            'https://user:secret@updates.example/manifest.json',
            'https://updates.example/manifest.json?download=1',
            'https://updates.example/manifest.json#frag',
            'https://updates.example:8443/manifest.json',
            'https://updates.example/$(VERSION).json',
        ):
            with self.assertRaises(release_lib.ReleaseError):
                release_lib.validate_update_url(value, 'WATT_UPDATE_MANIFEST_URL')


class WorkflowTests(unittest.TestCase):
    def test_workflow_is_pinned_and_does_not_interpolate_untrusted_input(self) -> None:
        import yaml
        workflow = yaml.safe_load((ROOT / '.github/workflows/release.yml').read_text())
        # PyYAML parses the YAML 1.1 key "on" as True.
        triggers = workflow.get('on', workflow.get(True))
        self.assertEqual(set(triggers), {'push', 'pull_request'})
        self.assertNotIn('pull_request_target', triggers)
        self.assertEqual(workflow['permissions'], {'contents': 'read'})
        release_job = workflow['jobs']['release-please']
        self.assertEqual(
            release_job['permissions'],
            {'contents': 'write', 'pull-requests': 'write', 'issues': 'write'},
        )
        self.assertEqual(workflow['jobs']['build']['permissions'], {'contents': 'write'})
        self.assertEqual(workflow['jobs']['build']['runs-on'], 'xcode-27')
        cask = workflow['jobs']['homebrew-cask']
        self.assertEqual(cask['permissions'], {'contents': 'read'})
        self.assertEqual(cask['needs'], ['release-please', 'build'])
        self.assertEqual(cask['if'], "needs.build.result == 'success'")
        gate = next(step for step in cask['steps'] if step.get('name') == 'Decide whether the cask can move')
        self.assertEqual(gate['id'], 'cask-gate')
        self.assertEqual(gate['run'], 'bash scripts/cask-rollout-gate.sh')
        self.assertNotIn('${{', gate['run'])
        update = next(step for step in cask['steps'] if step.get('name') == 'Update the Homebrew tap')
        self.assertEqual(update['if'], "steps.cask-gate.outputs.bump == 'true'")
        self.assertLess(
            [step.get('name') for step in cask['steps']].index('Decide whether the cask can move'),
            [step.get('name') for step in cask['steps']].index('Update the Homebrew tap'),
        )
        self.assertEqual(update['env']['HOMEBREW_TAP_DEPLOY_KEY'], '${{ secrets.HOMEBREW_TAP_DEPLOY_KEY }}')
        self.assertNotIn('HOMEBREW_TAP_TOKEN', update['env'])
        self.assertNotIn('${{', update['run'])
        delete = next(step for step in cask['steps'] if step.get('name') == 'Delete the Homebrew deploy key')
        self.assertEqual(delete['if'], 'always()')
        self.assertIn('homebrew-tap-deploy-key', delete['run'])
        self.assertNotIn('HOMEBREW_TAP_DEPLOY_KEY', delete['run'])
        pages = workflow['jobs']['pages']
        self.assertEqual(pages['permissions'], {'pages': 'write', 'id-token': 'write'})
        self.assertEqual(pages['environment']['name'], 'github-pages')
        self.assertEqual(pages['needs'], ['release-please', 'build'])
        seen = set()

        def walk(node: object) -> None:
            if isinstance(node, dict):
                if 'uses' in node:
                    uses = node['uses']
                    self.assertRegex(uses, r'@([0-9a-f]{40})( # .+)?$')
                    seen.add(uses.split('@', 1)[1].split(' ', 1)[0])
                if 'run' in node:
                    self.assertNotIn('${{', node['run'])
                for value in node.values():
                    walk(value)
            elif isinstance(node, list):
                for value in node:
                    walk(value)

        walk(workflow)
        self.assertEqual(
            seen,
            {
                '3d3c42e5aac5ba805825da76410c181273ba90b1',
                '45996ed1f6d02564a971a2fa1b5860e934307cf7',
                'fc324d3547104276b827a68afc52ff2a11cc49c9',
                '368f82528645a54fb793d4d04e342629a3f51346',
            },
        )

    def test_release_checkout_uses_the_validated_pull_request_branch(self) -> None:
        import re
        import yaml
        pattern = r'^release-please--branches--main(--components--[A-Za-z0-9._-]+)?$'
        compiled = re.compile(pattern)
        self.assertIsNotNone(compiled.fullmatch('release-please--branches--main'))
        self.assertIsNotNone(compiled.fullmatch('release-please--branches--main--components--Watt'))
        for rejected in (
            'main',
            'release-please--branches--main--components--Watt extra',
            'release-please--branches--main;touch /tmp/pwned',
            'release-please--branches--other',
            'refs/heads/release-please--branches--main--components--Watt',
        ):
            self.assertIsNone(compiled.fullmatch(rejected), rejected)

        workflow = yaml.safe_load((ROOT / '.github/workflows/release.yml').read_text())
        steps = workflow['jobs']['release-please']['steps']
        opened = "steps.release.outputs.prs_created == 'true' && steps.release.outputs.release_created != 'true'"
        resolve = next(step for step in steps if step.get('name') == 'Resolve the release pull request branch')
        checkout = next(step for step in steps if step.get('name') == 'Checkout the release pull request')
        sync = next(step for step in steps if step.get('name') == 'Sync CFBundleVersion onto the release pull request')
        self.assertEqual(resolve['id'], 'release-branch')
        self.assertEqual(resolve['if'], opened)
        self.assertEqual(checkout['if'], opened)
        self.assertEqual(sync['if'], opened)
        self.assertEqual(
            resolve['env']['RELEASE_PLEASE_BRANCH'],
            "${{ fromJSON(steps.release.outputs.pr || '{}').headBranchName }}",
        )
        self.assertIn(pattern, resolve['run'])
        self.assertIn('GITHUB_OUTPUT', resolve['run'])
        self.assertNotIn('${{', resolve['run'])
        self.assertEqual(checkout['with']['ref'], '${{ steps.release-branch.outputs.branch }}')
        self.assertNotIn('persist-credentials', checkout.get('with', {}))
        self.assertEqual(sync['env']['RELEASE_PLEASE_BRANCH'], '${{ steps.release-branch.outputs.branch }}')
        self.assertEqual(sync['run'], 'bash scripts/sync-release-branch.sh')
        self.assertNotIn('${{', sync['run'])
        script = (ROOT / 'scripts' / 'sync-release-branch.sh').read_text()
        self.assertIn(pattern, script)
        self.assertIn('git push origin "HEAD:${branch}"', script)
        self.assertNotIn('HEAD:release-please--branches--main', script)

    def test_sync_release_branch_refuses_unexpected_branches(self) -> None:
        script = str(ROOT / 'scripts' / 'sync-release-branch.sh')
        head = subprocess.run(
            ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
            cwd=ROOT, capture_output=True, text=True, check=True,
        ).stdout.strip()
        for name in (
            'release-please--branches--main',
            'release-please--branches--main--components--Watt',
        ):
            self.assertNotEqual(head, name)
            accepted = run(['bash', script], env={'RELEASE_PLEASE_BRANCH': name})
            self.assertEqual(accepted.returncode, 1, accepted.stdout + accepted.stderr)
            self.assertIn('this checkout', accepted.stderr)
            self.assertNotIn('unexpected release branch', accepted.stderr)
        for name in (
            '',
            'main',
            'release-please--branches--main --components--Watt',
            'release-please--branches--main;touch /tmp/pwned',
        ):
            rejected = run(['bash', script], env={'RELEASE_PLEASE_BRANCH': name})
            self.assertEqual(rejected.returncode, 1, rejected.stdout + rejected.stderr)
            self.assertIn('unexpected release branch', rejected.stderr)

    def test_shell_scripts_parse(self) -> None:
        for name in (
            'release-archive.sh',
            'sync-release-branch.sh',
            'upload-release-assets.sh',
            'update-homebrew-cask.sh',
            'publish-pages-update.sh',
            'stage-pages-site.sh',
            'verify-pages-artifact.sh',
            'preserve-pages-updates.sh',
            'check-pages-artifact.sh',
            'cask-rollout-gate.sh',
            'retry_on_timeout.sh',
        ):
            result = subprocess.run(['bash', '-n', str(ROOT / 'scripts' / name)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)


class ReadinessTests(unittest.TestCase):
    def info(self) -> dict[str, str]:
        return {
            'CFBundleIdentifier': 'com.example.watt',
            'WATTHelperTrustMode': 'protected-installation',
            'WATTUpdateManifestURL': 'https://updates.example/manifest.json',
            'WATTUpdateArtifactURL': 'https://updates.example/Watt.tar',
            'WATTUpdatePublicKey': base64.b64encode(b'\x11' * 32).decode('ascii'),
        }

    def test_distribution_accepts_ad_hoc_cdhash_without_a_team_or_ticket(self) -> None:
        self.assertEqual(release_readiness.distribution_plist_failures(self.info()), [])
        detail = 'Identifier=com.example.watt\nSignature=adhoc\nTeamIdentifier=not set\nCodeDirectory v=20400 flags=0x10000(runtime)\n'
        requirement = 'designated => identifier "com.example.watt" and cdhash H"00112233445566778899aabbccddeeff00112233"\n'
        self.assertEqual(
            release_readiness.codesign_identity_failures(detail, requirement, 'Watt', distribution=True),
            [],
        )
        self.assertEqual(
            release_readiness.entitlement_failures('', 'Watt', distribution=True, main_app=True),
            [],
        )

    def test_distribution_rejects_developer_id_certificate_mode_and_weak_requirements(self) -> None:
        certificate = self.info()
        certificate['WATTHelperTrustMode'] = 'certificate'
        certificate['WATTSigningTeam'] = 'ABCDE12345'
        reasons = release_readiness.distribution_plist_failures(certificate)
        self.assertTrue(any('cdhash' in reason for reason in reasons))
        self.assertFalse(any('team' in reason.lower() for reason in reasons))
        placeholder = self.info()
        placeholder['CFBundleIdentifier'] = 'dev.watt.verification'
        self.assertTrue(release_readiness.distribution_plist_failures(placeholder))
        missing_key = self.info()
        del missing_key['WATTUpdatePublicKey']
        self.assertTrue(any('public key' in reason for reason in release_readiness.distribution_plist_failures(missing_key)))
        developer_id = 'Authority=Developer ID Application: Example (ABCDE12345)\nSignature=adhoc\nflags=0x10000(runtime)\n'
        requirement = 'designated => identifier "com.example.watt" and cdhash H"00112233445566778899aabbccddeeff00112233"\n'
        self.assertTrue(release_readiness.codesign_identity_failures(developer_id, requirement, 'Watt', distribution=True))
        no_hash = 'Signature=adhoc\nflags=0x10000(runtime)\n'
        anchor = 'designated => anchor apple generic and identifier "com.example.watt"\n'
        self.assertTrue(release_readiness.codesign_identity_failures(no_hash, anchor, 'Watt', distribution=True))
        self.assertTrue(release_readiness.codesign_identity_failures(
            'Signature=adhoc\n', requirement, 'Watt', distribution=True))
        self.assertTrue(release_readiness.entitlement_failures(
            'com.apple.security.cs.disable-library-validation', 'Watt', distribution=True, main_app=True))
        self.assertTrue(release_readiness.entitlement_failures(
            'com.apple.security.get-task-allow', 'Watt', distribution=True, main_app=True))

    def test_distribution_accepts_the_production_identity_and_pages_endpoints(self) -> None:
        manifest, artifact = release_lib.load_update_endpoints(ROOT)
        info = self.info()
        info['CFBundleIdentifier'] = 'io.github.ben-ranford.watt'
        info['WATTUpdateManifestURL'] = manifest
        info['WATTUpdateArtifactURL'] = artifact
        self.assertEqual(release_readiness.distribution_plist_failures(info, endpoints=(manifest, artifact)), [])
        mismatched = dict(info)
        mismatched['WATTUpdateArtifactURL'] = 'https://updates.example/Watt.tar'
        self.assertTrue(release_readiness.distribution_plist_failures(mismatched, endpoints=(manifest, artifact)))
        missing_mode = self.info()
        del missing_mode['WATTHelperTrustMode']
        self.assertTrue(any('cdhash' in reason for reason in release_readiness.distribution_plist_failures(missing_mode)))

    def test_local_mode_still_accepts_a_developer_certificate(self) -> None:
        detail = 'Authority=Developer ID Application: Example (ABCDE12345)\nflags=0x10000(runtime)\n'
        requirement = 'designated => anchor apple generic and identifier "com.example.watt"\n'
        self.assertEqual(
            release_readiness.codesign_identity_failures(detail, requirement, 'Watt', distribution=False),
            [],
        )


# Homebrew 7.0.13 `brew style` and `brew audit --cask --strict --online` accept
# this shape. Only version and sha256 change between releases.
HOMEBREW_CASK_GOLDEN = """\
cask "watt" do
  version "1.1.0"
  sha256 "13356021d01279e35fa7f113f4627543654463ed2cd633f025ea7bdddd371337"

  url "https://github.com/ben-ranford/watt/releases/download/v#{version}/Watt-#{version}.zip"
  name "Watt?"
  desc "Menu bar power draw monitor"
  homepage "https://github.com/ben-ranford/watt"

  auto_updates true
  depends_on macos: :ventura

  app "Watt.app"

  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Watt.app"]
  end

  zap launchctl: "io.github.ben-ranford.watt.helper",
      trash:     [
        "/Library/Application Support/Watt",
        "/Library/Application Support/Watt-maintenance-result.json",
        "/Library/LaunchDaemons/io.github.ben-ranford.watt.helper.plist",
        "/Library/PrivilegedHelperTools/io.github.ben-ranford.watt.helper",
        "~/Library/Application Support/Watt",
        "~/Library/Preferences/io.github.ben-ranford.watt.plist",
      ]

  caveats <<~EOS
    Watt is ad-hoc signed and is not notarised.
    This cask removes the quarantine attribute so Gatekeeper does not block the first launch.
  EOS
end
"""


class HomebrewCaskTests(unittest.TestCase):
    def test_rendered_cask_matches_the_homebrew_7_golden(self) -> None:
        text = render_homebrew_cask.render_cask(
            version='1.1.0',
            sha256='13356021d01279e35fa7f113f4627543654463ed2cd633f025ea7bdddd371337',
            bundle_id='io.github.ben-ranford.watt',
            minimum_system_version='13.0',
        )
        self.assertEqual(text, HOMEBREW_CASK_GOLDEN)
        self.assertNotIn('postflight do', text)
        self.assertNotIn('>= :', text)
        other = render_homebrew_cask.render_cask(
            version='9.9.9',
            sha256='cd' * 32,
            bundle_id='io.github.ben-ranford.watt',
            minimum_system_version='13.0',
        )
        changed = [
            (left, right)
            for left, right in zip(text.splitlines(), other.splitlines(), strict=True)
            if left != right
        ]
        self.assertEqual(
            changed,
            [
                ('  version "1.1.0"', '  version "9.9.9"'),
                (
                    '  sha256 "13356021d01279e35fa7f113f4627543654463ed2cd633f025ea7bdddd371337"',
                    '  sha256 "' + ('cd' * 32) + '"',
                ),
            ],
        )

    def test_rendered_cask_uses_the_release_zip_and_gatekeeper_caveats(self) -> None:
        text = render_homebrew_cask.render_cask(
            version='1.2.3',
            sha256='ab' * 32,
            bundle_id='com.example.watt',
            minimum_system_version='13.0',
        )
        self.assertIn('cask "watt" do', text)
        self.assertIn('version "1.2.3"', text)
        self.assertIn('sha256 "' + ('ab' * 32) + '"', text)
        self.assertIn('releases/download/v#{version}/Watt-#{version}.zip', text)
        self.assertIn('depends_on macos: :ventura', text)
        self.assertNotIn('>= :', text)
        self.assertNotIn('postflight do', text)
        self.assertIn('auto_updates true', text)
        self.assertIn('app "Watt.app"', text)
        self.assertIn('"~/Library/Application Support/Watt"', text)
        self.assertIn('"~/Library/Preferences/com.example.watt.plist"', text)
        self.assertIn('"/Library/Application Support/Watt"', text)
        self.assertIn('"/Library/Application Support/Watt-maintenance-result.json"', text)
        self.assertIn('"/Library/LaunchDaemons/com.example.watt.helper.plist"', text)
        self.assertIn('"/Library/PrivilegedHelperTools/com.example.watt.helper"', text)
        self.assertIn('launchctl: "com.example.watt.helper"', text)
        self.assertIn('postflight_steps do', text)
        self.assertIn(
            'run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Watt.app"]',
            text,
        )
        self.assertNotIn('Control-click', text)
        self.assertNotIn('Open Anyway', text)
        self.assertNotIn('no-quarantine', text)
        self.assertNotIn('no_quarantine', text)
        self.assertNotIn('notarytool', text)
        self.assertIn('not notarised', text)
        with self.assertRaises(release_lib.ReleaseError):
            render_homebrew_cask.render_cask(
                version='1.2.3', sha256='AB' * 32, bundle_id='com.example.watt', minimum_system_version='13.0')
        with self.assertRaises(release_lib.ReleaseError):
            render_homebrew_cask.macos_dependency('27.0')

    def test_zip_metadata_reads_the_app_plist(self) -> None:
        import io
        import plistlib
        import zipfile
        info = {
            'CFBundleIdentifier': 'com.example.watt',
            'CFBundleShortVersionString': '1.2.3',
            'LSMinimumSystemVersion': '14.0',
        }
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, 'w') as archive:
            archive.writestr('Watt.app/Contents/Info.plist', plistlib.dumps(info))
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'Watt-1.2.3.zip'
            path.write_bytes(buffer.getvalue())
            read = render_homebrew_cask.zip_app_info(path)
            self.assertEqual(read['marketing'], '1.2.3')
            self.assertEqual(read['identity'], 'com.example.watt')
            text = render_homebrew_cask.render_cask(
                version=str(read['marketing']),
                sha256=render_homebrew_cask.sha256_file(path),
                bundle_id=str(read['identity']),
                minimum_system_version=str(read['minimum']),
            )
            self.assertIn('depends_on macos: :sonoma', text)
            self.assertNotIn('>= :', text)
            self.assertNotIn('postflight do', text)

    def test_unset_deploy_key_skips_without_calling_git(self) -> None:
        env = os.environ.copy()
        env.pop('HOMEBREW_TAP_DEPLOY_KEY', None)
        result = subprocess.run(
            ['bash', 'scripts/update-homebrew-cask.sh'],
            cwd=ROOT,
            env=env,
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('HOMEBREW_TAP_DEPLOY_KEY is unset', result.stdout)
        self.assertIn('Skipping', result.stdout)

    def test_deploy_key_is_not_a_personal_access_token(self) -> None:
        script = (ROOT / 'scripts/update-homebrew-cask.sh').read_text()
        notes = (ROOT / 'RELEASING.md').read_text()
        for text in (script, notes):
            self.assertNotIn('HOMEBREW_TAP_TOKEN', text)
        self.assertIn('git@github.com:ben-ranford/homebrew-tap.git', script)
        self.assertIn('IdentitiesOnly=yes', script)
        self.assertIn('StrictHostKeyChecking=yes', script)
        self.assertIn('chmod 0600', script)
        self.assertIn(
            'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl',
            script,
        )
        self.assertNotIn('echo "$HOMEBREW_TAP_DEPLOY_KEY"', script)
        self.assertNotIn("echo '${HOMEBREW_TAP_DEPLOY_KEY}'", script)
        self.assertIn('HOMEBREW_TAP_DEPLOY_KEY', notes)
        self.assertIn('write-access deploy key on `ben-ranford/homebrew-tap` only', notes)
        self.assertIn('unprotected', notes)

    def test_bad_tag_does_not_print_the_deploy_key(self) -> None:
        secret = 'watt-deploy-key-sentinel-do-not-print'
        env = os.environ.copy()
        env['HOMEBREW_TAP_DEPLOY_KEY'] = secret
        env['RELEASE_TAG'] = 'not-a-release'
        env['GITHUB_REPOSITORY'] = 'ben-ranford/watt'
        env['GITHUB_TOKEN'] = 'unused'
        result = subprocess.run(
            ['bash', 'scripts/update-homebrew-cask.sh'],
            cwd=ROOT,
            env=env,
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('Refusing release tag.', result.stderr)
        self.assertNotIn(secret, result.stdout)
        self.assertNotIn(secret, result.stderr)

    def test_deploy_key_pushes_the_cask_over_ssh_without_printing_the_key(self) -> None:
        import io
        import plistlib
        import zipfile

        secret = 'watt-deploy-key-sentinel-do-not-print'
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bare = root / 'tap.git'
            seed = root / 'seed'
            runner_temp = root / 'runner-temp'
            bin_dir = root / 'bin'
            runner_temp.mkdir()
            bin_dir.mkdir()
            subprocess.run(['git', 'init', '--bare', '-b', 'main', str(bare)], check=True, capture_output=True)
            subprocess.run(['git', 'init', '-b', 'main', str(seed)], check=True, capture_output=True)
            subprocess.run(['git', '-C', str(seed), 'config', 'user.email', 'test@example.com'], check=True)
            subprocess.run(['git', '-C', str(seed), 'config', 'user.name', 'Test'], check=True)
            (seed / 'README').write_text('tap\n')
            subprocess.run(['git', '-C', str(seed), 'add', 'README'], check=True)
            subprocess.run(['git', '-C', str(seed), 'commit', '-m', 'init'], check=True, capture_output=True)
            subprocess.run(['git', '-C', str(seed), 'remote', 'add', 'origin', str(bare)], check=True)
            subprocess.run(['git', '-C', str(seed), 'push', 'origin', 'HEAD:main'], check=True, capture_output=True)

            info = {
                'CFBundleIdentifier': 'io.github.ben-ranford.watt',
                'CFBundleShortVersionString': '1.2.3',
                'LSMinimumSystemVersion': '13.0',
            }
            buffer = io.BytesIO()
            with zipfile.ZipFile(buffer, 'w') as archive:
                archive.writestr('Watt.app/Contents/Info.plist', plistlib.dumps(info))
            zip_path = root / 'Watt-1.2.3.zip'
            zip_path.write_bytes(buffer.getvalue())
            ssh_log = root / 'ssh.log'
            (bin_dir / 'gh').write_text(
                '#!/usr/bin/env python3\n'
                'import os, shutil, sys\n'
                'from pathlib import Path\n'
                'args = sys.argv[1:]\n'
                'if len(args) >= 2 and args[0] == "release" and args[1] == "view":\n'
                '    print("false")\n'
                '    raise SystemExit(0)\n'
                'if len(args) >= 2 and args[0] == "release" and args[1] == "download":\n'
                '    directory = args[args.index("--dir") + 1]\n'
                '    pattern = args[args.index("--pattern") + 1]\n'
                '    shutil.copyfile(os.environ["CASK_ZIP"], Path(directory) / pattern)\n'
                '    raise SystemExit(0)\n'
                'sys.stderr.write("unexpected gh invocation\\n")\n'
                'raise SystemExit(2)\n'
            )
            (bin_dir / 'ssh').write_text(
                '#!/usr/bin/env python3\n'
                'import os, sys\n'
                'from pathlib import Path\n'
                'args = sys.argv[1:]\n'
                'key = None\n'
                'known = None\n'
                'index = 0\n'
                'while index < len(args):\n'
                '    if args[index] == "-i" and index + 1 < len(args):\n'
                '        key = args[index + 1]\n'
                '        index += 2\n'
                '        continue\n'
                '    if args[index] == "-o" and index + 1 < len(args):\n'
                '        option = args[index + 1]\n'
                '        if option.startswith("UserKnownHostsFile="):\n'
                '            known = option.split("=", 1)[1]\n'
                '        index += 2\n'
                '        continue\n'
                '    index += 1\n'
                'log = Path(os.environ["SSH_LOG"])\n'
                'with log.open("a") as handle:\n'
                '    handle.write("INVOKED\\n")\n'
                '    if os.environ.get("HOMEBREW_TAP_DEPLOY_KEY"):\n'
                '        handle.write("key_still_in_environment\\n")\n'
                '    if key is None:\n'
                '        handle.write("missing identity file\\n")\n'
                '    else:\n'
                '        handle.write("key_mode=%o\\n" % (os.stat(key).st_mode & 0o777))\n'
                '    handle.write("host_ok=%s\\n" % ("git@github.com" in args))\n'
                '    handle.write("identities=%s\\n" % ("IdentitiesOnly=yes" in args))\n'
                '    handle.write("strict=%s\\n" % ("StrictHostKeyChecking=yes" in args))\n'
                '    if known:\n'
                '        handle.write(Path(known).read_text())\n'
                'command = args[-1]\n'
                'bare = os.environ["TAP_BARE"]\n'
                'if command.startswith("git-upload-pack"):\n'
                '    os.execvp("git", ["git", "upload-pack", bare])\n'
                'if command.startswith("git-receive-pack"):\n'
                '    os.execvp("git", ["git", "receive-pack", bare])\n'
                'sys.stderr.write("unexpected ssh command\\n")\n'
                'raise SystemExit(1)\n'
            )
            os.chmod(bin_dir / 'gh', 0o755)
            os.chmod(bin_dir / 'ssh', 0o755)
            env = os.environ.copy()
            env.update({
                'HOMEBREW_TAP_DEPLOY_KEY': secret,
                'GITHUB_TOKEN': 'unused',
                'GITHUB_REPOSITORY': 'ben-ranford/watt',
                'RELEASE_TAG': 'v1.2.3',
                'SOURCE_REPO': 'ben-ranford/homebrew-tap',
                'RUNNER_TEMP': str(runner_temp),
                'CASK_ZIP': str(zip_path),
                'SSH_LOG': str(ssh_log),
                'TAP_BARE': str(bare),
                'PATH': str(bin_dir) + os.pathsep + env.get('PATH', ''),
            })
            env.pop('GIT_SSH_COMMAND', None)
            result = subprocess.run(
                ['bash', 'scripts/update-homebrew-cask.sh'],
                cwd=ROOT,
                env=env,
                text=True,
                capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            combined = result.stdout + result.stderr
            self.assertNotIn(secret, combined)
            self.assertIn('Updated ben-ranford/homebrew-tap Casks/watt.rb for 1.2.3.', result.stdout)
            self.assertFalse((runner_temp / 'homebrew-tap-deploy-key').exists())
            log_text = ssh_log.read_text()
            self.assertNotIn(secret, log_text)
            self.assertNotIn('key_still_in_environment', log_text)
            self.assertNotIn('missing identity file', log_text)
            self.assertIn('key_mode=600', log_text)
            self.assertNotIn('key_mode=644', log_text)
            self.assertIn('host_ok=True', log_text)
            self.assertIn('identities=True', log_text)
            self.assertIn('strict=True', log_text)
            self.assertIn(
                'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl',
                log_text,
            )
            self.assertGreaterEqual(log_text.count('INVOKED'), 2)
            showed = subprocess.run(
                ['git', '--git-dir', str(bare), 'log', '-1', '--format=%an%n%ae%n%s'],
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertEqual(
                showed.stdout.splitlines(),
                [
                    'github-actions[bot]',
                    '41898282+github-actions[bot]@users.noreply.github.com',
                    'watt 1.2.3',
                ],
            )
            cask_text = subprocess.run(
                ['git', '--git-dir', str(bare), 'show', 'main:Casks/watt.rb'],
                check=True,
                capture_output=True,
                text=True,
            ).stdout
            expected = render_homebrew_cask.render_cask(
                version='1.2.3',
                sha256=render_homebrew_cask.sha256_file(zip_path),
                bundle_id='io.github.ben-ranford.watt',
                minimum_system_version='13.0',
            )
            self.assertEqual(cask_text, expected)
            self.assertIn('postflight_steps do', cask_text)
            self.assertNotIn('postflight do', cask_text)
            self.assertNotIn('>= :', cask_text)
            self.assertIn('com.apple.quarantine', cask_text)

    def test_archive_script_has_no_notarisation_path(self) -> None:
        text = (ROOT / 'scripts/release-archive.sh').read_text()
        self.assertNotIn('notarytool', text)
        self.assertNotIn('APPLE_', text)
        self.assertNotIn('developer-id', text)
        self.assertIn('CODE_SIGN_IDENTITY=-', text)
        self.assertEqual(text.count('ENABLE_TESTABILITY=NO'), 2)
        self.assertEqual(text.count('CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO'), 2)
        hardened = (ROOT / 'Resources/Entitlements/HardenedRuntime.entitlements').read_text()
        self.assertNotIn('<key>com.apple.security.get-task-allow</key>', hardened)
        release_config = (ROOT / 'Watt.xcodeproj/project.pbxproj').read_text()
        self.assertIn(
            '"CODE_SIGN_ENTITLEMENTS" = "Resources/Entitlements/HardenedRuntime.entitlements"',
            release_config,
        )
        self.assertNotIn('WattDebug.entitlements"; "name" = "Release"', release_config)
        self.assertNotIn('INFOPLIST_KEY_WATT', text)
        self.assertIn('WATT_HELPER_TRUST_MODE=protected-installation', text)
        self.assertIn('WATT_UPDATE_MANIFEST_URL=$manifest_url', text)
        self.assertIn('WATT_UPDATE_ARTIFACT_URL=$artifact_url', text)
        self.assertIn('WATT_UPDATE_PUBLIC_KEY=$public_key', text)
        self.assertIn('--changelog "$root/CHANGELOG.md"', text)
        self.assertIn('--marketing-version "$version"', text)
        self.assertIn('--rollout "$root/Resources/ReleaseRollout.json"', text)
        self.assertLess(text.index('--changelog "$root/CHANGELOG.md"'), text.index('--rollout "$root/Resources/ReleaseRollout.json"'))
        self.assertLess(text.index('--rollout "$root/Resources/ReleaseRollout.json"'), text.index('--output "$output/Watt-$version-update-manifest.json"'))
        self.assertNotIn('${WATT_UPDATE_MANIFEST_URL', text)
        self.assertNotIn('${WATT_UPDATE_ARTIFACT_URL', text)
        self.assertLess(text.index('check_archived_plist.py'), text.index('\nset +e\n'))


class AppIconTests(unittest.TestCase):
    def _snapshot(self) -> Path:
        temporary = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, temporary)
        for relative in (
            'Resources/Assets.xcassets/AppIcon.appiconset',
            'Resources/Assets.xcassets/WattAppIcon.imageset',
            'Resources/App/Info.plist',
            'Watt.xcodeproj/project.pbxproj',
        ):
            source = ROOT / relative
            destination = temporary / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            if source.is_dir():
                shutil.copytree(source, destination)
            else:
                shutil.copy2(source, destination)
        return temporary

    def test_repository_icon_is_not_the_placeholder(self) -> None:
        import check_app_icon
        self.assertEqual(
            check_app_icon.PLACEHOLDER_SHA256,
            '948a88b21b68fcf435b3ca2c4c5b8be2900ee3f585cf7befe6dc3e9f97ad9b67',
        )
        self.assertEqual(check_app_icon.failures(ROOT), [])
        result = run([sys.executable, 'scripts/check_app_icon.py'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('PASS', result.stdout)
        archive = (ROOT / 'scripts/release-archive.sh').read_text()
        self.assertLess(archive.index('check_app_icon.py'), archive.index('xcodebuild archive'))

    def test_empty_set_placeholder_bytes_and_grey_icon_fail(self) -> None:
        import check_app_icon
        root = self._snapshot()
        catalog = root / 'Resources/Assets.xcassets/AppIcon.appiconset/Contents.json'
        document = json.loads(catalog.read_text())
        document['images'] = []
        catalog.write_text(json.dumps(document))
        empty = check_app_icon.failures(root)
        self.assertTrue(any('images array is empty' in reason for reason in empty))

        root = self._snapshot()
        icon = root / 'Resources/Assets.xcassets/AppIcon.appiconset/icon_16x16.png'
        digest = hashlib.sha256(icon.read_bytes()).hexdigest()
        matched = check_app_icon.failures(root, placeholder_sha256=digest)
        self.assertTrue(any('icon_16x16.png matches the placeholder icon' in reason for reason in matched))

        root = self._snapshot()
        grey = root / 'Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png'
        _write_flat_png(grey, 1024, (196, 196, 196, 255))
        grey_failures = check_app_icon.failures(root)
        self.assertTrue(any('no dark body and green reading dot' in reason for reason in grey_failures))

        root = self._snapshot()
        plist_path = root / 'Resources/App/Info.plist'
        import plistlib
        with plist_path.open('rb') as handle:
            info = plistlib.load(handle)
        info.pop('CFBundleIconName', None)
        with plist_path.open('wb') as handle:
            plistlib.dump(info, handle)
        self.assertTrue(any(
            'CFBundleIconName' in reason for reason in check_app_icon.failures(root)
        ))


def _write_flat_png(path: Path, pixels: int, color: tuple[int, int, int, int]) -> None:
    import struct
    import zlib
    row = b'\x00' + bytes(color) * pixels
    compressed = zlib.compress(row * pixels)
    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
    ihdr = struct.pack('>IIBBBBB', pixels, pixels, 8, 6, 0, 0, 0)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr) + chunk(b'IDAT', compressed) + chunk(b'IEND', b''))


class ArchivedPlistTests(unittest.TestCase):
    def test_archived_plist_must_contain_the_settings_xcodebuild_was_given(self) -> None:
        import plistlib
        manifest = 'https://updates.example/manifest.json'
        artifact = 'https://updates.example/Watt.tar'
        public = base64.b64encode(b'\x11' * 32).decode('ascii')
        compiled = {
            'WATTHelperTrustMode': 'protected-installation',
            'WATTUpdateManifestURL': manifest,
            'WATTUpdateArtifactURL': artifact,
            'WATTUpdatePublicKey': public,
        }
        self.assertEqual(
            release_readiness.compiled_release_plist_failures(
                compiled, manifest_url=manifest, artifact_url=artifact, public_key=public),
            [],
        )
        # The 1.0.0 archive had none of these keys. Preflight then failed softly
        # and the Pages job skipped the manifest.
        dropped = release_readiness.compiled_release_plist_failures(
            {'CFBundleIdentifier': 'io.github.ben-ranford.watt'},
            manifest_url=manifest, artifact_url=artifact, public_key=public,
        )
        self.assertTrue(any('WATTHelperTrustMode' in reason for reason in dropped))
        self.assertTrue(any('missing WATTUpdateManifestURL' in reason for reason in dropped))
        self.assertTrue(any('missing WATTUpdateArtifactURL' in reason for reason in dropped))
        self.assertTrue(any('missing WATTUpdatePublicKey' in reason for reason in dropped))
        unexpanded = dict(compiled, WATTUpdateManifestURL='$(WATT_UPDATE_MANIFEST_URL)')
        self.assertTrue(any(
            'did not expand WATTUpdateManifestURL' in reason
            for reason in release_readiness.compiled_release_plist_failures(
                unexpanded, manifest_url=manifest, artifact_url=artifact, public_key=public)
        ))
        empty = dict(compiled, WATTUpdateArtifactURL='')
        self.assertTrue(any(
            'missing WATTUpdateArtifactURL' in reason
            for reason in release_readiness.compiled_release_plist_failures(
                empty, manifest_url=manifest, artifact_url=artifact, public_key='')
        ))
        local = {
            'WATTHelperTrustMode': 'protected-installation',
            'WATTUpdateManifestURL': '',
            'WATTUpdateArtifactURL': '',
            'WATTUpdatePublicKey': '',
        }
        self.assertEqual(release_readiness.compiled_release_plist_failures(local), [])
        certificate = dict(compiled, WATTHelperTrustMode='certificate')
        self.assertTrue(release_readiness.compiled_release_plist_failures(
            certificate, manifest_url=manifest, artifact_url=artifact))
        other_key = base64.b64encode(b'\x22' * 32).decode('ascii')
        mismatched = dict(compiled, WATTUpdatePublicKey=other_key)
        self.assertTrue(any(
            'does not match' in reason
            for reason in release_readiness.compiled_release_plist_failures(
                mismatched, manifest_url=manifest, artifact_url=artifact, public_key=public)
        ))
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            present = root / 'present.plist'
            missing = root / 'missing.plist'
            with present.open('wb') as handle:
                plistlib.dump(compiled, handle)
            with missing.open('wb') as handle:
                plistlib.dump({'CFBundleIdentifier': 'io.github.ben-ranford.watt'}, handle)
            ok = run([
                sys.executable, 'scripts/check_archived_plist.py', str(present),
                '--manifest-url', manifest, '--artifact-url', artifact, '--public-key', public,
            ])
            self.assertEqual(ok.returncode, 0, ok.stderr)
            self.assertIn('PASS', ok.stdout)
            self.assertNotIn(public, ok.stdout + ok.stderr)
            failed = run([
                sys.executable, 'scripts/check_archived_plist.py', str(missing),
                '--manifest-url', manifest, '--artifact-url', artifact, '--public-key', public,
            ])
            self.assertEqual(failed.returncode, 1)
            self.assertIn('BLOCKED', failed.stderr)
            self.assertIn('missing WATTUpdateManifestURL', failed.stderr)
            self.assertIn('WATTHelperTrustMode', failed.stderr)
            self.assertNotIn(manifest, failed.stderr)
            self.assertNotIn(public, failed.stderr)


class PagesPublishTests(unittest.TestCase):
    def _ustar(self, payload: bytes = b'watt-app') -> bytes:
        import io
        import tarfile

        buffer = io.BytesIO()
        with tarfile.open(fileobj=buffer, mode='w', format=tarfile.USTAR_FORMAT) as archive:
            info = tarfile.TarInfo('Watt.app/Contents/Info.plist')
            info.size = len(payload)
            archive.addfile(info, io.BytesIO(payload))
        data = buffer.getvalue()
        self.assertEqual(data[257:262], b'ustar')
        return data

    def _serve(self, files: dict[str, bytes | None]):
        import threading
        from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self) -> None:  # noqa: N802
                name = self.path.rsplit('/', 1)[-1]
                body = files.get(name)
                if body is None:
                    self.send_response(404)
                    self.end_headers()
                    return
                self.send_response(200)
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, _format: str, *_args: object) -> None:
                return

        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        return f'http://127.0.0.1:{server.server_port}/download/v1.2.3'

    def test_stages_both_files_from_one_release_and_skips_when_the_manifest_is_absent(self) -> None:
        manifest = b'{"payload":"e30=","signature":"YQ=="}'
        archive = self._ustar()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root / 'github-output'
            site = root / 'site'
            present = run(
                ['bash', 'scripts/publish-pages-update.sh'],
                env={
                    'RELEASE_TAG': 'v1.2.3',
                    'RELEASE_ASSET_BASE': self._serve({
                        'Watt-1.2.3-update-manifest.json': manifest,
                        'Watt-1.2.3.tar': archive,
                    }),
                    'PAGES_DIR': str(site),
                    'GITHUB_OUTPUT': str(output),
                },
            )
            self.assertEqual(present.returncode, 0, present.stderr)
            self.assertEqual((site / 'updates/manifest.json').read_bytes(), manifest)
            self.assertEqual((site / 'updates/Watt.tar').read_bytes(), archive)
            self.assertIn('deploy=true', output.read_text())
            missing_output = root / 'missing-output'
            missing = run(
                ['bash', 'scripts/publish-pages-update.sh'],
                env={
                    'RELEASE_TAG': 'v1.2.3',
                    'RELEASE_ASSET_BASE': self._serve({}),
                    'PAGES_DIR': str(root / 'absent'),
                    'GITHUB_OUTPUT': str(missing_output),
                },
            )
            self.assertEqual(missing.returncode, 0, missing.stderr)
            self.assertIn('Skipping', missing.stdout)
            self.assertIn('deploy=false', missing_output.read_text())
            self.assertFalse((root / 'absent').exists())

    def test_oversized_tar_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            result = run(
                ['bash', 'scripts/publish-pages-update.sh'],
                env={
                    'RELEASE_TAG': 'v1.2.3',
                    'RELEASE_ASSET_BASE': self._serve({
                        'Watt-1.2.3-update-manifest.json': b'{"payload":"e30=","signature":"YQ=="}',
                        'Watt-1.2.3.tar': self._ustar(b'x' * 64),
                    }),
                    'PAGES_DIR': str(Path(temporary) / 'site'),
                    'PAGES_MAX_BYTES': '8',
                },
            )
        self.assertEqual(result.returncode, 1)
        self.assertIn('GitHub Pages file limit', result.stderr)

    def test_update_staging_keeps_an_existing_landing_page(self) -> None:
        manifest = b'{"payload":"e30=","signature":"YQ=="}'
        archive = self._ustar()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            site = root / 'site'
            site.mkdir()
            (site / 'index.html').write_text('<!DOCTYPE html><title>Watt?</title>', encoding='utf-8')
            result = run(
                ['bash', 'scripts/publish-pages-update.sh'],
                env={
                    'RELEASE_TAG': 'v1.2.3',
                    'RELEASE_ASSET_BASE': self._serve({
                        'Watt-1.2.3-update-manifest.json': manifest,
                        'Watt-1.2.3.tar': archive,
                    }),
                    'PAGES_DIR': str(site),
                },
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('Watt?', (site / 'index.html').read_text(encoding='utf-8'))
            self.assertEqual((site / 'updates/manifest.json').read_bytes(), manifest)
            self.assertEqual((site / 'updates/Watt.tar').read_bytes(), archive)


class PagesSiteTests(unittest.TestCase):
    def _png(self, width: int, height: int, rgb: tuple[int, int, int] = (20, 20, 22)) -> bytes:
        import struct
        import zlib

        def chunk(tag: bytes, data: bytes) -> bytes:
            return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)

        raw = b''.join(b'\x00' + bytes(rgb) * width for _ in range(height))
        return (
            b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 9))
            + chunk(b'IEND', b'')
        )

    def _site(self, root: Path) -> None:
        docs = root / 'docs'
        shots = docs / 'screenshots'
        shots.mkdir(parents=True)
        (docs / 'index.html').write_text('<!DOCTYPE html><title>Watt?</title><p>Native macOS menu-bar app that shows live charger, system and battery power in watts.</p>', encoding='utf-8')
        (docs / 'site.css').write_text('body { color: #111; }\n', encoding='utf-8')
        (docs / 'icon.png').write_bytes(self._png(8, 8))
        (docs / 'social-preview.png').write_bytes(self._png(1280, 640))
        for name in (
            'menu-bar-light.png', 'menu-bar-dark.png',
            'panel-light.png', 'panel-dark.png',
            'settings-light.png', 'settings-dark.png',
        ):
            (shots / name).write_bytes(self._png(4, 4, (30, 30, 32)))

    def _ustar(self) -> bytes:
        import io
        import tarfile

        buffer = io.BytesIO()
        with tarfile.open(fileobj=buffer, mode='w', format=tarfile.USTAR_FORMAT) as archive:
            payload = b'watt-app'
            info = tarfile.TarInfo('Watt.app/Contents/Info.plist')
            info.size = len(payload)
            archive.addfile(info, io.BytesIO(payload))
        return buffer.getvalue()

    def test_landing_page_copy_keeps_update_bytes(self) -> None:
        manifest = b'{"payload":"e30=","signature":"YQ=="}'
        archive = self._ustar()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self._site(root)
            dest = root / 'out'
            updates = dest / 'updates'
            updates.mkdir(parents=True)
            (updates / 'manifest.json').write_bytes(manifest)
            (updates / 'Watt.tar').write_bytes(archive)
            staged = run(
                ['bash', 'scripts/stage-pages-site.sh'],
                env={'PAGES_SOURCE': str(root), 'PAGES_DIR': str(dest)},
            )
            self.assertEqual(staged.returncode, 0, staged.stderr)
            self.assertEqual((updates / 'manifest.json').read_bytes(), manifest)
            self.assertEqual((updates / 'Watt.tar').read_bytes(), archive)
            self.assertTrue((dest / 'index.html').is_file())
            checked = run(
                ['bash', 'scripts/verify-pages-artifact.sh'],
                env={'PAGES_DIR': str(dest), 'PAGES_REQUIRE_UPDATES': 'true'},
            )
            self.assertEqual(checked.returncode, 0, checked.stderr)
            self.assertIn('landing page', checked.stdout)

    def test_site_source_cannot_carry_an_updates_directory(self) -> None:
        manifest = b'{"payload":"e30=","signature":"YQ=="}'
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self._site(root)
            (root / 'docs/updates').mkdir()
            (root / 'docs/updates/manifest.json').write_bytes(b'{"payload":"bm8=","signature":"bm8="}')
            dest = root / 'out'
            (dest / 'updates').mkdir(parents=True)
            (dest / 'updates/manifest.json').write_bytes(manifest)
            result = run(
                ['bash', 'scripts/stage-pages-site.sh'],
                env={'PAGES_SOURCE': str(root), 'PAGES_DIR': str(dest)},
            )
            self.assertEqual(result.returncode, 1, result.stdout)
            self.assertIn('docs/updates', result.stderr)
            self.assertEqual((dest / 'updates/manifest.json').read_bytes(), manifest)
            self.assertFalse((dest / 'index.html').exists())

    def test_verify_rejects_an_artifact_without_updates(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self._site(root)
            dest = root / 'out'
            staged = run(
                ['bash', 'scripts/stage-pages-site.sh'],
                env={'PAGES_SOURCE': str(root), 'PAGES_DIR': str(dest)},
            )
            self.assertEqual(staged.returncode, 0, staged.stderr)
            missing = run(
                ['bash', 'scripts/verify-pages-artifact.sh'],
                env={'PAGES_DIR': str(dest), 'PAGES_REQUIRE_UPDATES': 'true'},
            )
            self.assertEqual(missing.returncode, 1)
            self.assertIn('updates/manifest.json', missing.stderr)

    def test_preserve_copies_published_updates_and_refuses_to_drop_them(self) -> None:
        manifest = b'{"payload":"e30=","signature":"YQ=="}'
        archive = self._ustar()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)

            import threading
            from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

            files: dict[str, bytes | None] = {
                'manifest.json': manifest,
                'Watt.tar': archive,
            }

            class Handler(BaseHTTPRequestHandler):
                def do_GET(self) -> None:  # noqa: N802
                    body = files.get(self.path.rsplit('/', 1)[-1])
                    if body is None:
                        self.send_response(404)
                        self.end_headers()
                        return
                    self.send_response(200)
                    self.send_header('Content-Length', str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)

                def log_message(self, _format: str, *_args: object) -> None:
                    return

            server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            self.addCleanup(server.shutdown)
            self.addCleanup(server.server_close)
            base = f'http://127.0.0.1:{server.server_port}/updates'
            dest = root / 'site'
            output = root / 'output'
            preserved = run(
                ['bash', 'scripts/preserve-pages-updates.sh'],
                env={
                    'PAGES_DIR': str(dest),
                    'PAGES_UPDATES_BASE': base,
                    'GITHUB_OUTPUT': str(output),
                },
            )
            self.assertEqual(preserved.returncode, 0, preserved.stderr)
            self.assertEqual((dest / 'updates/manifest.json').read_bytes(), manifest)
            self.assertEqual((dest / 'updates/Watt.tar').read_bytes(), archive)
            self.assertIn('updates=preserved', output.read_text(encoding='utf-8'))

            files.clear()
            seeded = root / 'seeded'
            (seeded / 'updates').mkdir(parents=True)
            (seeded / 'updates/manifest.json').write_bytes(manifest)
            (seeded / 'updates/Watt.tar').write_bytes(archive)
            refused = run(
                ['bash', 'scripts/preserve-pages-updates.sh'],
                env={'PAGES_DIR': str(seeded), 'PAGES_UPDATES_BASE': base},
            )
            self.assertEqual(refused.returncode, 1, refused.stdout)
            self.assertIn('Refusing to deploy without the published updates', refused.stderr)
            self.assertEqual((seeded / 'updates/manifest.json').read_bytes(), manifest)
            self.assertEqual((seeded / 'updates/Watt.tar').read_bytes(), archive)

            files['manifest.json'] = b'<html>not a manifest</html>'
            files['Watt.tar'] = archive
            invalid = run(
                ['bash', 'scripts/preserve-pages-updates.sh'],
                env={'PAGES_DIR': str(root / 'invalid'), 'PAGES_UPDATES_BASE': base},
            )
            self.assertEqual(invalid.returncode, 1)
            self.assertFalse((root / 'invalid/updates').exists())

            files.clear()
            absent_dir = root / 'absent'
            absent_output = root / 'absent-output'
            absent = run(
                ['bash', 'scripts/preserve-pages-updates.sh'],
                env={
                    'PAGES_DIR': str(absent_dir),
                    'PAGES_UPDATES_BASE': base,
                    'PAGES_ALLOW_ABSENT': 'true',
                    'GITHUB_OUTPUT': str(absent_output),
                },
            )
            self.assertEqual(absent.returncode, 0, absent.stderr)
            self.assertIn('updates=absent', absent_output.read_text(encoding='utf-8'))
            self.assertFalse((absent_dir / 'updates').exists())

            files['manifest.json'] = manifest
            partial = run(
                ['bash', 'scripts/preserve-pages-updates.sh'],
                env={
                    'PAGES_DIR': str(root / 'partial'),
                    'PAGES_UPDATES_BASE': base,
                    'PAGES_ALLOW_ABSENT': 'true',
                },
            )
            self.assertEqual(partial.returncode, 1, partial.stdout)
            self.assertIn('Refusing to deploy without the published updates', partial.stderr)
            self.assertFalse((root / 'partial/updates').exists())

    def test_repository_pages_artifact_contains_the_landing_page_and_updates(self) -> None:
        result = run(['bash', 'scripts/check-pages-artifact.sh'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('PASS: landing page and updates/', result.stdout)

    def test_landing_page_has_no_trackers_and_matches_the_readme(self) -> None:
        import struct
        html = (ROOT / 'docs/index.html').read_text(encoding='utf-8')
        css = (ROOT / 'docs/site.css').read_text(encoding='utf-8')
        lowered = html.lower()
        for token in (
            '<script', 'googleapis', 'googletagmanager', 'google-analytics',
            'plausible', 'gtag', 'cdn.jsdelivr', 'unpkg.com', 'fonts.google',
        ):
            self.assertNotIn(token, lowered, token)
        self.assertNotIn('http://', lowered)
        self.assertNotIn('@import', css.lower())
        self.assertNotIn('url(http', css.lower())
        pitch = 'Native macOS menu-bar app that shows live charger, system and battery power in watts.'
        self.assertIn(pitch, html)
        self.assertIn('brew install --cask ben-ranford/tap/watt', html)
        self.assertIn('https://github.com/ben-ranford/watt/releases/latest', html)
        self.assertIn('Watt is ad-hoc signed and is not notarised, so Gatekeeper blocks the first launch of a zip or disk image.', html)
        self.assertIn('Control-click Watt and choose Open, then choose Open.', html)
        self.assertIn('com.apple.quarantine', html)
        self.assertIn('https://github.com/ben-ranford/watt/blob/main/LICENSE', html)
        self.assertIn('https://github.com/ben-ranford/watt"', html)
        self.assertIn('og:image', html)
        self.assertIn('content="1280"', html)
        self.assertIn('content="640"', html)
        self.assertIn('summary_large_image', html)
        for name in (
            'menu-bar-light.png', 'menu-bar-dark.png',
            'panel-light.png', 'panel-dark.png',
            'settings-light.png', 'settings-dark.png',
        ):
            self.assertIn(f'screenshots/{name}', html)
            self.assertTrue((ROOT / 'docs/screenshots' / name).is_file(), name)
        preview = (ROOT / 'docs/social-preview.png').read_bytes()
        self.assertEqual(preview[:8], b'\x89PNG\r\n\x1a\n')
        self.assertEqual(struct.unpack('>II', preview[16:24]), (1280, 640))
        icon = ROOT / 'Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png'
        self.assertEqual((ROOT / 'docs/icon.png').read_bytes(), icon.read_bytes())
        readme = (ROOT / 'README.md').read_text(encoding='utf-8')
        for name in (
            'menu-bar-light.png', 'menu-bar-dark.png',
            'panel-light.png', 'panel-dark.png',
            'settings-light.png', 'settings-dark.png',
        ):
            self.assertIn(f'docs/screenshots/{name}', readme)
        self.assertLess(readme.find('# watt'), readme.find('docs/screenshots/menu-bar-light.png'))
        self.assertIn('## Security', readme)
        self.assertIn('brew install --cask ben-ranford/tap/watt', readme)

    def test_release_and_docs_deploys_both_keep_updates(self) -> None:
        import yaml
        release = yaml.safe_load((ROOT / '.github/workflows/release.yml').read_text())
        pages = release['jobs']['pages']
        names = [step.get('name') for step in pages['steps']]
        self.assertLess(names.index('Stage manifest and tar'), names.index('Stage the landing page'))
        self.assertLess(names.index('Stage the landing page'), names.index('Check the Pages artifact'))
        self.assertLess(names.index('Check the Pages artifact'), names.index('Upload Pages artifact'))
        self.assertLess(names.index('Upload Pages artifact'), names.index('Deploy to GitHub Pages'))
        deploy_if = "steps.stage.outputs.deploy == 'true'"
        for name in ('Stage the landing page', 'Check the Pages artifact', 'Upload Pages artifact', 'Deploy to GitHub Pages'):
            step = next(step for step in pages['steps'] if step.get('name') == name)
            self.assertEqual(step.get('if'), deploy_if, name)
        stage = next(step for step in pages['steps'] if step.get('name') == 'Stage the landing page')
        verify = next(step for step in pages['steps'] if step.get('name') == 'Check the Pages artifact')
        self.assertEqual(stage['run'], 'bash source/scripts/stage-pages-site.sh')
        self.assertEqual(verify['run'], 'bash source/scripts/verify-pages-artifact.sh')
        self.assertEqual(verify['env']['PAGES_REQUIRE_UPDATES'], 'true')
        self.assertNotIn('preserve-pages-updates.sh', '\n'.join(
            step.get('run', '') for step in pages['steps'] if isinstance(step.get('run'), str)
        ))
        self.assertEqual(pages['concurrency'], {'group': 'pages', 'cancel-in-progress': False})

        workflow = yaml.safe_load((ROOT / '.github/workflows/pages.yml').read_text())
        triggers = workflow.get('on', workflow.get(True))
        self.assertEqual(set(triggers), {'pull_request', 'push'})
        self.assertNotIn('pull_request_target', triggers)
        self.assertEqual(workflow['permissions'], {'contents': 'read'})
        self.assertEqual(workflow['jobs']['verify']['name'], 'Pages artifact')
        self.assertEqual(workflow['jobs']['verify']['steps'][-1]['run'], 'bash scripts/check-pages-artifact.sh')
        deploy = workflow['jobs']['deploy']
        self.assertEqual(deploy['concurrency'], {'group': 'pages', 'cancel-in-progress': False})
        self.assertEqual(deploy['if'], "github.event_name == 'push' && github.ref == 'refs/heads/main'")
        self.assertEqual(deploy['permissions'], {'contents': 'read', 'pages': 'write', 'id-token': 'write'})
        self.assertEqual(deploy['environment']['name'], 'github-pages')
        deploy_names = [step.get('name') for step in deploy['steps']]
        self.assertLess(deploy_names.index('Preserve published updates'), deploy_names.index('Stage the landing page'))
        self.assertLess(deploy_names.index('Stage the landing page'), deploy_names.index('Check the Pages artifact'))
        self.assertLess(deploy_names.index('Check the Pages artifact'), deploy_names.index('Upload Pages artifact'))
        preserve = next(step for step in deploy['steps'] if step.get('name') == 'Preserve published updates')
        self.assertEqual(preserve['env']['PAGES_UPDATES_BASE'], 'https://ben-ranford.github.io/watt/updates')
        self.assertNotIn('PAGES_ALLOW_ABSENT', preserve.get('env', {}))
        for step in workflow['jobs']['verify']['steps'] + deploy['steps']:
            if 'run' in step:
                self.assertNotIn('${{', step['run'])
            if 'uses' in step:
                self.assertRegex(step['uses'], r'@[0-9a-f]{40}( # .+)?$')


class ContributorTemplateTests(unittest.TestCase):
    def test_issue_forms_match_the_contributing_checks(self) -> None:
        import yaml
        config = yaml.safe_load((ROOT / '.github/ISSUE_TEMPLATE/config.yml').read_text())
        self.assertIs(config['blank_issues_enabled'], False)
        if (ROOT / 'SECURITY.md').exists():
            about = ' '.join(link['url'] for link in config['contact_links'])
            self.assertIn('security/advisories/new', about)
        else:
            self.assertNotIn('contact_links', config)
        bug = yaml.safe_load((ROOT / '.github/ISSUE_TEMPLATE/bug_report.yml').read_text())
        feature = yaml.safe_load((ROOT / '.github/ISSUE_TEMPLATE/feature_request.yml').read_text())
        self.assertEqual(bug['labels'], ['bug'])
        self.assertEqual(feature['labels'], ['feature'])
        bug_ids = [item['id'] for item in bug['body'] if 'id' in item]
        self.assertEqual(
            bug_ids,
            ['macos-version', 'watt-version', 'mac-model', 'steps', 'expected', 'actual', 'logs'],
        )
        feature_ids = [item['id'] for item in feature['body'] if 'id' in item]
        self.assertEqual(feature_ids, ['problem', 'proposed-behavior', 'acceptance-criteria'])
        template = (ROOT / '.github/pull_request_template.md').read_text()
        for line in (
            '## Summary',
            'Closes #',
            '## Change type',
            'Unit tests pass',
            'xcodebuild',
            'gitleaks',
            'scripts/test_release_pipeline.py',
            'screenshots',
            'CHANGELOG.md',
        ):
            self.assertIn(line, template)
        self.assertIn('CONTRIBUTING.md', (ROOT / 'README.md').read_text())


class PullRequestTitleTests(unittest.TestCase):
    def test_accepts_release_please_and_version_bumps(self) -> None:
        import check_pr_title
        for title in (
            'fix: compile update endpoints into the release Info.plist',
            'feat: publish under io.github.ben-ranford.watt',
            'feat!: change the reading',
            'feat(menu-bar)!: change the reading',
            'chore(main): release 1.0.1',
            'ci: build and test on macOS',
            'docs: follow Standard Readme',
            'test: read the marketing version instead of assuming 1.0.0',
            'build: enable hardened runtime with minimal entitlements',
            'perf: sample less often',
            'refactor(helper): bind the daemon',
            'revert: restore the panel',
            'style: wrap the settings row',
            'deps: bump gitleaks',
        ):
            self.assertIsNone(check_pr_title.title_error(title), title)

    def test_rejects_titles_release_please_cannot_read(self) -> None:
        import check_pr_title
        for title in (
            'Update the readme',
            'Feat: uppercase type',
            'fix:',
            'fix: ',
            'fix:missing space',
            'feat(): empty scope',
            'chore(main): release 1.0.1\nfix: hidden',
            ' fix: leading space',
            'fix: trailing space ',
            'wip: not a type',
        ):
            self.assertIsNotNone(check_pr_title.title_error(title), title)

    def test_cli_reads_the_environment_and_does_not_need_the_shell(self) -> None:
        accepted = run(
            [sys.executable, 'scripts/check_pr_title.py'],
            env={'PR_TITLE': 'chore: add issue and PR templates'},
        )
        self.assertEqual(accepted.returncode, 0, accepted.stderr)
        self.assertIn('PASS', accepted.stdout)
        missing = run([sys.executable, 'scripts/check_pr_title.py'], env={'PR_TITLE': ''})
        self.assertEqual(missing.returncode, 1, missing.stdout)
        cleaned = os.environ.copy()
        cleaned.pop('PR_TITLE', None)
        unset_result = subprocess.run(
            [sys.executable, 'scripts/check_pr_title.py'],
            cwd=ROOT,
            env=cleaned,
            text=True,
            capture_output=True,
        )
        self.assertEqual(unset_result.returncode, 1)
        self.assertIn('PR_TITLE is not set', unset_result.stderr)

    def test_workflow_passes_the_title_in_the_environment(self) -> None:
        import yaml
        workflow = yaml.safe_load((ROOT / '.github/workflows/pr-title.yml').read_text())
        triggers = workflow.get('on', workflow.get(True))
        self.assertEqual(set(triggers), {'pull_request'})
        self.assertIn('edited', triggers['pull_request']['types'])
        self.assertNotIn('pull_request_target', triggers)
        self.assertEqual(workflow['permissions'], {'contents': 'read'})
        job = workflow['jobs']['conventional-commit']
        self.assertEqual(job['name'], 'Conventional commit')
        self.assertEqual(job['runs-on'], 'ubuntu-latest')
        check = next(step for step in job['steps'] if step.get('name') == 'Check the pull request title')
        self.assertEqual(check['env']['PR_TITLE'], '${{ github.event.pull_request.title }}')
        self.assertNotIn('${{', check['run'])
        self.assertEqual(check['run'], 'python3 scripts/check_pr_title.py')
        checkout = next(step for step in job['steps'] if 'uses' in step)
        self.assertRegex(checkout['uses'], r'@([0-9a-f]{40})( # .+)?$')


class CIWorkflowTests(unittest.TestCase):
    def test_pull_requests_still_build_and_test(self) -> None:
        import yaml
        workflow = yaml.safe_load((ROOT / '.github/workflows/ci.yml').read_text())
        triggers = workflow.get('on', workflow.get(True))
        self.assertIn('pull_request', triggers)
        self.assertIn('push', triggers)
        job = workflow['jobs']['macos']
        self.assertEqual(job['name'], 'macOS')
        self.assertEqual(job['runs-on'], 'xcode-27')
        steps = {step['name']: step['run'] for step in job['steps'] if 'run' in step}
        self.assertIn('xcodebuild build', steps['Build Debug and Release'])
        self.assertIn('build_configuration Debug', steps['Build Debug and Release'])
        self.assertIn('build_configuration Release', steps['Build Debug and Release'])
        test = steps['Unit tests (xcodebuild)']
        self.assertIn('xcodebuild test', test)
        self.assertIn('-only-testing:WattTests', test)
        self.assertIn('-test-timeouts-enabled YES', test)
        self.assertIn('-default-test-execution-time-allowance 120', test)
        self.assertIn('-maximum-test-execution-time-allowance 120', test)
        self.assertIn('bash scripts/retry_on_timeout.sh 600 1 --', test)
        self.assertIn('swift test --configuration debug', steps['Unit tests (swift test)'])
        self.assertIn('ditto -c -k --keepParent', steps['Zip the Release app'])
        self.assertIn('codesign --verify --verbose=2', steps['Zip the Release app'])
        self.assertIn('print_release_update_settings.py --check-plist', steps['Zip the Release app'])
        release_build = steps['Build Debug and Release']
        self.assertIn('python3 scripts/print_release_update_settings.py', release_build)
        self.assertIn('[[ "${configuration}" == "Release" ]]', release_build)
        for run in steps.values():
            self.assertNotIn('${{', run)
        packaged = next(step for step in job['steps'] if step.get('name') == 'Zip the Release app')
        uploaded = next(step for step in job['steps'] if step.get('name') == 'Upload the Release app')
        self.assertEqual(packaged['if'], "github.event_name == 'pull_request'")
        self.assertEqual(uploaded['if'], "github.event_name == 'pull_request'")
        self.assertRegex(uploaded['uses'], r'actions/upload-artifact@[0-9a-f]{40}( # .+)?$')
        self.assertEqual(uploaded['with']['name'], 'Watt-app-pr')
        self.assertEqual(uploaded['with']['retention-days'], 7)
        self.assertEqual(uploaded['with']['if-no-files-found'], 'error')
        self.assertTrue(str(uploaded['with']['path']).endswith('Watt.app.zip'))
        collect = next(step for step in job['steps'] if step.get('name') == 'Collect site screenshots')
        self.assertEqual(collect['if'], 'always()')
        self.assertIn('site-screenshots', collect['run'])
        self.assertIn('.site-screenshots', collect['run'])
        shots = next(step for step in job['steps'] if step.get('name') == 'Upload site screenshots')
        self.assertEqual(shots['if'], 'always()')
        self.assertEqual(shots['with']['name'], 'site-screenshots')
        self.assertEqual(shots['with']['path'], '${{ runner.temp }}/site-screenshots')
        self.assertEqual(shots['with']['if-no-files-found'], 'warn')
        self.assertIs(shots['with']['include-hidden-files'], True)
        self.assertIn('WATT_SCREENSHOT_DIR', steps['Unit tests (xcodebuild)'])
        names = [step.get('name') for step in job['steps']]
        self.assertLess(names.index('Unit tests (xcodebuild)'), names.index('Collect site screenshots'))
        self.assertLess(names.index('Collect site screenshots'), names.index('Upload site screenshots'))

    def test_release_update_settings_match_public_config(self) -> None:
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            'print_release_update_settings', ROOT / 'scripts/print_release_update_settings.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        printed = dict(module.settings())
        config = json.loads((ROOT / 'Resources/ReleaseIdentity.json').read_text())
        key = (ROOT / 'Resources/UpdatePublicKey.txt').read_text().strip()
        self.assertEqual(printed['WATT_UPDATE_MANIFEST_URL'], config['updateManifestURL'])
        self.assertEqual(printed['WATT_UPDATE_ARTIFACT_URL'], config['updateArtifactURL'])
        self.assertEqual(printed['WATT_UPDATE_PUBLIC_KEY'], key)
        self.assertEqual(len(base64.b64decode(key, validate=True)), 32)

    def test_watchdog_retries_only_a_timeout(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            marker = root / 'runs'
            script = (
                'import pathlib, sys, time\n'
                'path = pathlib.Path(sys.argv[1])\n'
                'count = int(path.read_text()) if path.exists() else 0\n'
                'path.write_text(str(count + 1))\n'
                'if count == 0:\n'
                '    time.sleep(30)\n'
            )
            command = [sys.executable, '-c', script, str(marker)]
            bundle = root / 'WattTests.xcresult'
            bundle.mkdir()
            (bundle / 'stale').write_text('x')
            retried = run(
                ['bash', 'scripts/retry_on_timeout.sh', '1', '1', '--', *command],
                env={'WATT_RESULT_BUNDLE': str(bundle)},
            )
            self.assertEqual(retried.returncode, 0, retried.stderr)
            self.assertEqual(marker.read_text(), '2')
            self.assertIn('retrying (1/1)', retried.stderr)
            self.assertFalse(bundle.exists())
            failures = root / 'failures'
            failed = run(
                [
                    'bash', 'scripts/retry_on_timeout.sh', '5', '1', '--',
                    sys.executable, '-c',
                    'import pathlib,sys; p=pathlib.Path(sys.argv[1]); p.write_text(str(int(p.read_text())+1) if p.exists() else "1"); raise SystemExit(65)',
                    str(failures),
                ],
            )
            self.assertEqual(failed.returncode, 65, failed.stderr)
            self.assertEqual(failures.read_text(), '1')
            self.assertNotIn('retrying', failed.stderr)

    def test_watchdog_exits_124_when_retries_are_spent(self) -> None:
        result = run(
            ['bash', 'scripts/retry_on_timeout.sh', '1', '0', '--', sys.executable, '-c', 'import time; time.sleep(30)'],
        )
        self.assertEqual(result.returncode, 124, result.stderr)
        missing = run([sys.executable, 'scripts/run_with_timeout.py', '--seconds', '2', '--', 'watt-missing-command'])
        self.assertEqual(missing.returncode, 127)
        usage = run(['bash', 'scripts/retry_on_timeout.sh'])
        self.assertEqual(usage.returncode, 2)
        refused = run(
            ['bash', 'scripts/retry_on_timeout.sh', '5', '0', '--', 'true'],
            env={'WATT_RESULT_BUNDLE': '/'},
        )
        self.assertEqual(refused.returncode, 2, refused.stderr)
        self.assertIn('refusing to delete', refused.stderr)


class RolloutTests(unittest.TestCase):
    def rollout(self, **overrides: object) -> dict:
        document = {
            'basis': 1_700_000_000,
            'interval': 86_400,
            'steps': [1, 2, 5, 10, 20, 50, 100],
            'paused': False,
            'percent': 1,
            'critical': False,
            'halted': False,
        }
        document.update(overrides)
        return rollout_manifest.canonical(document)

    def test_schedule_boundaries_match_the_client(self) -> None:
        basis = 1_700_000_000
        cases = {
            basis - 1: 0,
            basis: 1,
            basis + 86_399: 1,
            basis + 86_400: 2,
            basis + 86_400 * 2: 5,
            basis + 86_400 * 6: 100,
            basis + 86_400 * 30: 100,
        }
        rollout = self.rollout()
        for now, expected in cases.items():
            self.assertEqual(rollout_manifest.share(rollout, now), expected)
            self.assertEqual(rollout_manifest.share(rollout, now), expected)
        paused = self.rollout(paused=True, percent=5)
        self.assertEqual(rollout_manifest.share(paused, basis + 86_400 * 30), 5)
        critical = self.rollout(critical=True, percent=1)
        self.assertEqual(rollout_manifest.share(critical, basis - 10), 100)

    def test_payload_appends_rollout_without_changing_the_old_prefix(self) -> None:
        digest = hashlib.sha256(b'watt').digest()
        rollout = self.rollout()
        payload = release_lib.manifest_payload('dev.watt.example', 1_002_003, digest, '13.0', '### Fixes\n\n* steadier numbers', rollout)
        self.assertEqual(
            payload,
            b'{"identity":"dev.watt.example","build":1002003,"sha256":"'
            + base64.b64encode(digest)
            + b'","minimumSystemVersion":"13.0","notes":"### Fixes\\n\\n* steadier numbers","rollout":'
            + json.dumps(rollout, separators=(',', ':')).encode('ascii')
            + b'}',
        )
        plain = release_lib.manifest_payload('dev.watt.example', 1_002_003, digest, '13.0')
        self.assertTrue(payload.startswith(plain[:-1] + b',"notes":'))
        parsed = json.loads(payload)
        legacy = {key: parsed[key] for key in ('identity', 'build', 'sha256', 'minimumSystemVersion', 'notes')}
        self.assertEqual(legacy['notes'], '### Fixes\n\n* steadier numbers')
        self.assertNotIn('rollout', legacy)
        with self.assertRaises(release_lib.ReleaseError):
            release_lib.manifest_payload('dev.watt.example', 1_002_003, digest, '13.0', None, {'paused': True})

    def test_release_file_starts_at_one_percent_unless_critical(self) -> None:
        spec = json.loads((ROOT / 'Resources/ReleaseRollout.json').read_text(encoding='utf-8'))
        now = 1_700_000_000
        started = rollout_manifest.initial_rollout(spec, now)
        self.assertEqual(started['percent'], 1)
        self.assertEqual(started['basis'], now)
        self.assertFalse(started['critical'])
        self.assertFalse(rollout_manifest.cask_ready({'rollout': started}, now))
        critical = rollout_manifest.initial_rollout({**spec, 'critical': True}, now)
        self.assertTrue(critical['critical'])
        self.assertEqual(critical['percent'], 100)
        self.assertTrue(rollout_manifest.cask_ready({'rollout': critical}, now))
        self.assertTrue(rollout_manifest.cask_ready({'identity': 'dev.watt.example'}, now))
        self.assertFalse(rollout_manifest.cask_ready({'rollout': self.rollout(halted=True, paused=True, percent=0, critical=False)}, now))

    def test_actions_pause_advance_finish_and_halt(self) -> None:
        now = 1_700_000_000
        started = self.rollout()
        paused, changed = rollout_manifest.apply_action(started, 'pause', now + 86_400 * 2)
        self.assertTrue(changed)
        self.assertTrue(paused['paused'])
        self.assertEqual(paused['percent'], 5)
        self.assertFalse(paused['halted'])
        again, changed = rollout_manifest.apply_action(paused, 'sync', now + 86_400 * 4)
        self.assertFalse(changed)
        self.assertEqual(again, paused)
        resumed, changed = rollout_manifest.apply_action(paused, 'resume', now + 86_400 * 4)
        self.assertTrue(changed)
        self.assertFalse(resumed['paused'])
        self.assertEqual(rollout_manifest.share(resumed, now + 86_400 * 4), 5)
        advanced, changed = rollout_manifest.apply_action(resumed, 'advance', now + 86_400 * 4)
        self.assertTrue(changed)
        self.assertEqual(rollout_manifest.share(advanced, now + 86_400 * 4), 10)
        finished, changed = rollout_manifest.apply_action(advanced, 'finish', now + 86_400 * 4)
        self.assertTrue(changed)
        self.assertEqual(rollout_manifest.share(finished, now + 86_400 * 4), 100)
        self.assertTrue(rollout_manifest.cask_ready({'rollout': finished}, now + 86_400 * 4))
        halted, changed = rollout_manifest.apply_action(started, 'halt', now)
        self.assertTrue(changed)
        self.assertTrue(halted['halted'])
        self.assertEqual(halted['percent'], 0)
        self.assertFalse(rollout_manifest.cask_ready({'rollout': halted}, now))
        same, changed = rollout_manifest.apply_action(halted, 'halt', now + 10)
        self.assertFalse(changed)
        critical, changed = rollout_manifest.apply_action(halted, 'critical', now + 10)
        self.assertTrue(changed)
        self.assertTrue(critical['critical'])
        self.assertFalse(critical['halted'])
        self.assertTrue(rollout_manifest.cask_ready({'rollout': critical}, now + 10))

    def test_signed_rollout_fails_verification_when_changed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            pem = directory / 'key.pem'
            archive = directory / 'Watt-1.2.3.tar'
            output = directory / 'manifest.json'
            rollout = directory / 'rollout.json'
            archive.write_bytes(b'ustar-bytes')
            rollout.write_text(json.dumps({
                'critical': False,
                'interval': 86400,
                'steps': [1, 2, 5, 10, 20, 50, 100],
            }), encoding='utf-8')
            subprocess.run(['openssl', 'genpkey', '-algorithm', 'ED25519', '-out', str(pem)], check=True, capture_output=True)
            encoded = base64.b64encode(pem.read_bytes()).decode('ascii')
            signed = run(
                [sys.executable, 'scripts/sign-update-manifest.py', '--archive', str(archive), '--identity', 'dev.watt.example',
                 '--build', '1002003', '--minimum-system-version', '13.0', '--rollout', str(rollout),
                 '--rollout-basis', '1700000000', '--output', str(output)],
                env={'WATT_UPDATE_SIGNING_KEY': encoded},
            )
            self.assertEqual(signed.returncode, 0, signed.stderr)
            document = json.loads(output.read_text())
            payload = base64.b64decode(document['payload'])
            parsed = json.loads(payload)
            self.assertEqual(parsed['rollout']['percent'], 1)
            self.assertNotIn('notes', parsed)
            signature = base64.b64decode(document['signature'])
            public_pem = directory / 'public.pem'
            payload_path = directory / 'payload.json'
            signature_path = directory / 'sig.bin'
            payload_path.write_bytes(payload)
            signature_path.write_bytes(signature)
            subprocess.run(['openssl', 'pkey', '-in', str(pem), '-pubout', '-out', str(public_pem)], check=True, capture_output=True)
            verified = subprocess.run(
                ['openssl', 'pkeyutl', '-verify', '-pubin', '-inkey', str(public_pem), '-rawin', '-in', str(payload_path), '-sigfile', str(signature_path)],
                capture_output=True,
            )
            self.assertEqual(verified.returncode, 0, verified.stderr)
            payload_path.write_bytes(payload.replace(b'"percent":1', b'"percent":9'))
            tampered = subprocess.run(
                ['openssl', 'pkeyutl', '-verify', '-pubin', '-inkey', str(public_pem), '-rawin', '-in', str(payload_path), '-sigfile', str(signature_path)],
                capture_output=True,
            )
            self.assertNotEqual(tampered.returncode, 0)

            output.write_bytes(release_lib.signed_update_document(payload, signature) + b'\n')
            unchanged = run(
                [sys.executable, 'scripts/resign-rollout-manifest.py', '--manifest', str(output), '--archive', str(archive),
                 '--action', 'sync', '--now', '1700000000'],
                env={'WATT_UPDATE_SIGNING_KEY': encoded},
            )
            self.assertEqual(unchanged.returncode, 0, unchanged.stderr)
            self.assertIn('changed=false', unchanged.stdout)
            self.assertIn('cask=false', unchanged.stdout)
            self.assertEqual(output.read_bytes(), release_lib.signed_update_document(payload, signature) + b'\n')

            advanced = run(
                [sys.executable, 'scripts/resign-rollout-manifest.py', '--manifest', str(output), '--archive', str(archive),
                 '--action', 'advance', '--now', '1700000000'],
                env={'WATT_UPDATE_SIGNING_KEY': encoded},
            )
            self.assertEqual(advanced.returncode, 0, advanced.stderr)
            self.assertIn('changed=true', advanced.stdout)
            self.assertIn('deploy=true', advanced.stdout)
            republished = json.loads(base64.b64decode(json.loads(output.read_text())['payload']))
            self.assertEqual(republished['rollout']['percent'], 2)
            self.assertEqual(republished['sha256'], parsed['sha256'])
            self.assertEqual(archive.read_bytes(), b'ustar-bytes')

            refused = run(
                [sys.executable, 'scripts/resign-rollout-manifest.py', '--manifest', str(output), '--archive', str(archive),
                 '--action', 'pause', '--percent', 'nope', '--now', '1700000000'],
                env={'WATT_UPDATE_SIGNING_KEY': encoded},
            )
            self.assertEqual(refused.returncode, 1)
            self.assertIn('BLOCKED', refused.stderr)


class RolloutWorkflowTests(unittest.TestCase):
    def test_rollout_workflow_keeps_the_pages_guard(self) -> None:
        import yaml
        workflow = yaml.safe_load((ROOT / '.github/workflows/rollout.yml').read_text())
        triggers = workflow.get('on', workflow.get(True))
        self.assertEqual(set(triggers), {'schedule', 'workflow_dispatch'})
        self.assertNotIn('pull_request_target', triggers)
        self.assertEqual(workflow['permissions'], {'contents': 'read'})
        publish = workflow['jobs']['publish']
        self.assertEqual(publish['concurrency'], {'group': 'pages', 'cancel-in-progress': False})
        self.assertEqual(publish['permissions'], {'contents': 'read', 'pages': 'write', 'id-token': 'write'})
        self.assertEqual(publish['environment']['name'], 'github-pages')
        names = [step.get('name') for step in publish['steps']]
        self.assertLess(names.index('Preserve published updates'), names.index('Re-sign the rollout'))
        self.assertLess(names.index('Re-sign the rollout'), names.index('Stage the landing page'))
        self.assertLess(names.index('Check the Pages artifact'), names.index('Upload Pages artifact'))
        self.assertLess(names.index('Upload Pages artifact'), names.index('Deploy to GitHub Pages'))
        preserve = next(step for step in publish['steps'] if step.get('name') == 'Preserve published updates')
        self.assertEqual(preserve['env']['PAGES_ALLOW_ABSENT'], 'true')
        self.assertEqual(preserve['env']['PAGES_UPDATES_BASE'], 'https://ben-ranford.github.io/watt/updates')
        resign = next(step for step in publish['steps'] if step.get('name') == 'Re-sign the rollout')
        self.assertEqual(resign['if'], "steps.preserve.outputs.updates == 'preserved'")
        self.assertEqual(resign['env']['WATT_UPDATE_SIGNING_KEY'], '${{ secrets.WATT_UPDATE_SIGNING_KEY }}')
        self.assertNotIn('WATT_UPDATE_SIGNING_KEY', resign['run'])
        self.assertNotIn('${{', resign['run'])
        for name in ('Stage the landing page', 'Check the Pages artifact', 'Upload Pages artifact', 'Deploy to GitHub Pages'):
            step = next(step for step in publish['steps'] if step.get('name') == name)
            self.assertEqual(step.get('if'), "steps.rollout.outputs.deploy == 'true'")
        verify = next(step for step in publish['steps'] if step.get('name') == 'Check the Pages artifact')
        self.assertEqual(verify['env']['PAGES_REQUIRE_UPDATES'], 'true')
        cask = workflow['jobs']['cask']
        self.assertEqual(cask['if'], "needs.publish.outputs.cask == 'true'")
        self.assertEqual(cask['needs'], 'publish')
        update = next(step for step in cask['steps'] if step.get('name') == 'Update the Homebrew tap')
        self.assertEqual(update['env']['SOURCE_REPO'], 'ben-ranford/homebrew-tap')
        self.assertNotIn('${{', update['run'])
        delete = next(step for step in cask['steps'] if step.get('name') == 'Delete the Homebrew deploy key')
        self.assertEqual(delete['if'], 'always()')

        def walk(node: object) -> None:
            if isinstance(node, dict):
                if 'uses' in node:
                    self.assertRegex(node['uses'], r'@[0-9a-f]{40}( # .+)?$')
                if 'run' in node:
                    self.assertNotIn('${{', node['run'])
                for value in node.values():
                    walk(value)
            elif isinstance(node, list):
                for value in node:
                    walk(value)

        walk(workflow)


if __name__ == '__main__':
    unittest.main()
