#!/usr/bin/env python3
"""Checks for the release pipeline that can run without Xcode."""

from __future__ import annotations

import base64
import hashlib
import json
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
        self.assertEqual(release_lib.marketing_version(ROOT), '1.0.0')
        identity, build = release_lib.load_identity(ROOT)
        self.assertEqual(identity, 'dev.watt.verification')
        self.assertEqual(build, 1)
        self.assertEqual(release_lib.compiled_build(ROOT), 1)
        self.assertIn(1, release_lib.acceptable_builds('1.0.0', release=False))
        self.assertEqual(release_lib.acceptable_builds('1.0.0', release=True), {1_000_000})
        check = run([sys.executable, 'scripts/sync-release-version.py'])
        self.assertEqual(check.returncode, 0, check.stderr)
        self.assertIn('SKIP: configure-release-identity.py', check.stdout)
        release = run([sys.executable, 'scripts/sync-release-version.py', '--release'])
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
            xcconfig = (root / 'Config/Version.xcconfig').read_text().replace('1.0.0', version, 1)
            (root / 'Config/Version.xcconfig').write_text(xcconfig)
            result = run([sys.executable, str(ROOT / 'scripts/sync-release-version.py'), '--write', '--root', str(root)])
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(release_lib.load_identity(root), ('dev.watt.verification', 1_002_003))
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
        self.assertFalse(plan['embed_update'])
        self.assertTrue(any('ad-hoc' in message for message in plan['messages']))
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
        urls = release_plan.build_plan(
            {
                'RELEASE_VERSION': '1.2.3',
                'RELEASE_TAG': 'v1.2.3',
                'WATT_UPDATE_MANIFEST_URL': 'https://updates.example/manifest.json',
                'WATT_UPDATE_ARTIFACT_URL': 'https://github.com/ben-ranford/watt/releases/download/v1.2.3/Watt.tar?raw=1',
                'WATT_UPDATE_SIGNING_KEY': 'cGVt',
            },
            require_release=True,
        )
        self.assertTrue(any('query' in error or 'https' in error for error in urls['errors']))
        missing_key = release_plan.build_plan(
            {
                'RELEASE_VERSION': '1.2.3',
                'RELEASE_TAG': 'v1.2.3',
                'WATT_UPDATE_MANIFEST_URL': 'https://updates.example/manifest.json',
                'WATT_UPDATE_ARTIFACT_URL': 'https://updates.example/Watt.tar',
            },
            require_release=True,
        )
        self.assertTrue(missing_key['errors'])
        mismatch = release_plan.build_plan({'RELEASE_VERSION': '1.2.3', 'RELEASE_TAG': 'v9.9.9'}, require_release=True)
        self.assertTrue(mismatch['errors'])

    def test_complete_update_plan_omits_secret_material(self) -> None:
        plan = release_plan.build_plan(
            {
                'RELEASE_VERSION': '1.2.3',
                'RELEASE_TAG': 'v1.2.3',
                'WATT_UPDATE_SIGNING_KEY': 'cGVt',
                'WATT_UPDATE_MANIFEST_URL': 'https://updates.example/manifest.json',
                'WATT_UPDATE_ARTIFACT_URL': 'https://updates.example:443/Watt.tar',
            },
            require_release=True,
        )
        self.assertEqual(plan['errors'], [])
        self.assertEqual(plan['code_signing'], 'ad-hoc')
        self.assertTrue(plan['embed_update'])
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
                'WATT_UPDATE_MANIFEST_URL': 'https://updates.example/manifest.json',
                'WATT_UPDATE_ARTIFACT_URL': 'https://updates.example/Watt.tar',
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
        self.assertIn('MARKETING_VERSION = 1.0.0 // x-release-please-version', (ROOT / 'Config/Version.xcconfig').read_text())

    def test_show_build_settings_parser_selects_watt(self) -> None:
        text = """Build settings for action build and target WattHelper:
    MARKETING_VERSION = 9.9.9
    CURRENT_PROJECT_VERSION = 9
Build settings for action build and target Watt:
    MARKETING_VERSION = 1.2.3
    CURRENT_PROJECT_VERSION = 1002003
    PRODUCT_BUNDLE_IDENTIFIER = dev.watt.example
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
        self.assertIn('HOMEBREW_TAP_TOKEN', text)
        self.assertIn('WATT_UPDATE_SIGNING_KEY', text)

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
            },
        )

    def test_shell_scripts_parse(self) -> None:
        for name in ('release-archive.sh', 'sync-release-branch.sh', 'upload-release-assets.sh', 'update-homebrew-cask.sh'):
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

    def test_local_mode_still_accepts_a_developer_certificate(self) -> None:
        detail = 'Authority=Developer ID Application: Example (ABCDE12345)\nflags=0x10000(runtime)\n'
        requirement = 'designated => anchor apple generic and identifier "com.example.watt"\n'
        self.assertEqual(
            release_readiness.codesign_identity_failures(detail, requirement, 'Watt', distribution=False),
            [],
        )


class HomebrewCaskTests(unittest.TestCase):
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
        self.assertIn('depends_on macos: ">= :ventura"', text)
        self.assertIn('auto_updates true', text)
        self.assertIn('app "Watt.app"', text)
        self.assertIn('"~/Library/Application Support/Watt"', text)
        self.assertIn('"~/Library/Preferences/com.example.watt.plist"', text)
        self.assertIn('"/Library/Application Support/Watt"', text)
        self.assertIn('"/Library/Application Support/Watt-maintenance-result.json"', text)
        self.assertIn('"/Library/LaunchDaemons/com.example.watt.helper.plist"', text)
        self.assertIn('"/Library/PrivilegedHelperTools/com.example.watt.helper"', text)
        self.assertIn('launchctl: "com.example.watt.helper"', text)
        self.assertIn('Control-click Watt and choose Open', text)
        self.assertIn('System Settings → Privacy & Security and choose Open Anyway', text)
        self.assertNotIn('no-quarantine', text)
        self.assertNotIn('no_quarantine', text)
        self.assertNotIn('xattr', text)
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
            self.assertIn('>= :sonoma', text)

    def test_unset_tap_token_skips_without_calling_git(self) -> None:
        env = os.environ.copy()
        env.pop('HOMEBREW_TAP_TOKEN', None)
        result = subprocess.run(
            ['bash', 'scripts/update-homebrew-cask.sh'],
            cwd=ROOT,
            env=env,
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('HOMEBREW_TAP_TOKEN is unset', result.stdout)
        self.assertIn('Skipping', result.stdout)

    def test_archive_script_has_no_notarisation_path(self) -> None:
        text = (ROOT / 'scripts/release-archive.sh').read_text()
        self.assertNotIn('notarytool', text)
        self.assertNotIn('APPLE_', text)
        self.assertNotIn('developer-id', text)
        self.assertIn('CODE_SIGN_IDENTITY=-', text)
        self.assertIn('INFOPLIST_KEY_WATTHelperTrustMode=protected-installation', text)
        self.assertIn('WATT_HELPER_TRUST_MODE=protected-installation', text)


if __name__ == '__main__':
    unittest.main()
