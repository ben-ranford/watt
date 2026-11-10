#!/usr/bin/env python3
"""Nonpublishing verification of one explicitly selected Watt bundle."""
import argparse
import os
from pathlib import Path
import plistlib
import re
import stat
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_lib
import release_readiness


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['local', 'distribution-preflight'])
    parser.add_argument('application', type=Path)
    parser.add_argument('--clear-quarantine', action='store_true', help='remove quarantine only from this verified bundle')
    parser.add_argument('--archive', type=Path, help='create a new uncompressed USTAR archive after successful checks')
    args = parser.parse_args(argv)
    failures: list[str] = []

    def require(value, reason):
        if not value:
            failures.append(reason)

    def run(arguments, *, environment=None):
        result = subprocess.run(arguments, capture_output=True, text=True, env=environment)
        if result.returncode:
            raise ValueError('command refused: ' + Path(arguments[0]).name)
        return result.stdout + result.stderr

    try:
        application = args.application.absolute()
        require(application.suffix == '.app' and application.is_dir(), 'select an existing .app bundle')
        require(application.resolve() == application, 'bundle path contains a symlink; use its physical path')
        count = total = 0
        for directory, directories, files in os.walk(application, followlinks=False):
            for name in directories + files:
                item = Path(directory) / name
                metadata = item.lstat()
                require(stat.S_ISREG(metadata.st_mode) or stat.S_ISDIR(metadata.st_mode), 'unsupported link or special entry in bundle')
                require(metadata.st_mode & 0o022 == 0, 'group/other writable bundle entry')
                count += 1
                if stat.S_ISREG(metadata.st_mode):
                    total += metadata.st_size
        require(count <= 10000 and total <= 256 * 1024 * 1024, 'bundle exceeds archive profile bounds')
        with (application / 'Contents/Info.plist').open('rb') as handle:
            info = plistlib.load(handle)
        identity = info.get('CFBundleIdentifier', '')
        build = info.get('CFBundleVersion', '')
        require(isinstance(identity, str) and re.fullmatch(r'[A-Za-z0-9.-]+', identity), 'invalid app bundle identifier')
        require(isinstance(build, str) and re.fullmatch(r'[1-9][0-9]*', build) and int(build) <= 2**64 - 1, 'positive numeric CFBundleVersion required')
        require(info.get('LSMinimumSystemVersion') == '13.0', 'expected macOS 13 minimum')
        executable = application / 'Contents/MacOS/Watt'
        trust_mode = info.get('WATTHelperTrustMode', 'protected-installation')
        require(trust_mode in ('protected-installation', 'certificate'), 'unknown helper trust mode')
        signing_team = info.get('WATTSigningTeam', '')
        # Distribution does not require a team. Certificate mode is a local
        # Apple Development configuration, and preflight rejects it outright.
        if trust_mode == 'certificate' and args.mode != 'distribution-preflight':
            require(isinstance(signing_team, str) and re.fullmatch(r'[A-Z0-9]{10}', signing_team), 'certificate mode requires a ten-character Apple team')
        tools = [('Watt', identity), ('WattHelper', identity + '.helper'),
                 ('WattMaintenance', identity + '.maintenance'), ('WattHelperInstaller', identity + '.installer')]
        for name, expected in tools:
            binary = application / 'Contents/MacOS' / name
            require(binary.is_file() and os.access(binary, os.X_OK), 'missing executable: ' + name)
            if not binary.is_file():
                continue
            run(['/usr/bin/codesign', '--verify', '--strict', '--all-architectures', str(binary)])
            detail = run(['/usr/bin/codesign', '-dv', str(binary)])
            require('Identifier=' + expected + '\n' in detail, 'code identifier mismatch: ' + name)
            entitlement_result = subprocess.run(
                ['/usr/bin/codesign', '-d', '--entitlements', ':-', str(binary)],
                capture_output=True, text=True)
            entitlements = entitlement_result.stdout + entitlement_result.stderr
            require(entitlement_result.returncode == 0, 'unable to read entitlements: ' + name)
            failures.extend(release_readiness.entitlement_failures(
                entitlements, name, distribution=args.mode == 'distribution-preflight', main_app=name == 'Watt'))
            if trust_mode == 'certificate' and args.mode != 'distribution-preflight':
                require('TeamIdentifier=' + signing_team + '\n' in detail and 'Authority=' in detail,
                        'certificate mode requires configured Apple team signature: ' + name)
                if re.fullmatch(r'[A-Z0-9]{10}', signing_team):
                    run(['/usr/bin/codesign', '--verify', '--strict', '--all-architectures', '-R',
                         'anchor apple generic and certificate leaf[subject.OU] = "' + signing_team + '" and identifier "' + expected + '"', str(binary)])
            # Inspect both universal architecture requirement branches without interpreting a team as trust.
            requirement = run(['/usr/bin/codesign', '-d', '-r-', str(binary)])
            failures.extend(release_readiness.codesign_identity_failures(
                detail, requirement, name, distribution=args.mode == 'distribution-preflight'))
        run(['/usr/bin/codesign', '--verify', '--deep', '--strict', '--all-architectures', str(application)])
        symbols = run(['/usr/bin/nm', '-gj', str(executable)])
        require(not re.search(r'J[0-9]+FixtureLaunch|StoryFixtures|FixtureLaunchSelection', symbols), 'debug fixture symbols present')
        require((application / 'Contents/Library/LaunchDaemons' / (identity + '.helper.plist')).is_file(), 'missing bundled daemon plist')
        if args.mode == 'distribution-preflight':
            endpoints = release_lib.load_update_endpoints(Path(__file__).resolve().parents[1])
            failures.extend(release_readiness.distribution_plist_failures(info, endpoints=endpoints))
        if failures:
            raise ValueError('\n'.join(failures))
        if args.clear_quarantine:
            run(['/usr/bin/xattr', '-dr', 'com.apple.quarantine', str(application)])
        if args.archive:
            output = args.archive.absolute()
            require(not output.exists() and output.parent.is_dir(), 'archive must be a new output in an existing directory')
            require(application not in output.parents, 'archive cannot be inside the input bundle')
            if failures:
                raise ValueError('\n'.join(failures))
            # Exclusive reservation prevents overwriting an existing output.
            descriptor = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
            os.close(descriptor)
            try:
                environment = dict(os.environ, COPYFILE_DISABLE='1')
                run(['/usr/bin/tar', '--format', 'ustar', '-cf', str(output), '-C', str(application.parent), application.name], environment=environment)
                run([str(application / 'Contents/MacOS/WattMaintenance'), '--validate-archive', str(output)])
            except Exception:
                output.unlink(missing_ok=True)
                raise
            print('Validated USTAR archive:', output)
        if args.mode == 'distribution-preflight':
            passed = 'ad-hoc cdhash identity'
        else:
            passed = 'ad-hoc/certificate identities'
        print('PASS:', args.mode, 'bundle, embedded tools,', passed, 'and fixture exclusion verified')
        print('Local software evidence only; administrator, source and supported-host gates remain unverified.')
    except (ValueError, OSError, plistlib.InvalidFileException) as error:
        print('BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
