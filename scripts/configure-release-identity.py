#!/usr/bin/env python3
"""Provision all compiled and packaged identities from one reviewed local JSON input."""
import argparse
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--input', type=Path, default=root / 'Resources/ReleaseIdentity.json')
parser.add_argument('--write', action='store_true', help='apply the reviewed identity to source and native configuration')
args = parser.parse_args()
try:
    data = json.loads(args.input.read_text())
    identity, build = data['appIdentifier'], data['build']
    if set(data) != {'appIdentifier', 'build'} or not isinstance(identity, str) or not re.fullmatch(r'[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z0-9-]+)+', identity) or len(identity) > 128:
        raise ValueError('invalid appIdentifier')
    if isinstance(build, bool) or not isinstance(build, int) or not 0 < build < 2**64:
        raise ValueError('positive UInt64 build required')
    source_path = root / 'HelperShared/HelperXPC.swift'
    source = source_path.read_text()
    values = {'appIdentifier': identity, 'helperIdentifier': identity + '.helper', 'build': str(build)}
    changes = {}
    for name, value in values.items():
        pattern = r'(public static let ' + name + r' = )"[^"]*"'
        updated, count = re.subn(pattern, lambda m: m[1] + json.dumps(value), source)
        if count != 1:
            raise ValueError('missing unique compiled identity field: ' + name)
        source = updated
    changes[source_path] = source.encode()
    helper_path = root / 'Resources/Helper/Info.plist'
    helper = plistlib.loads(helper_path.read_bytes())
    helper['CFBundleIdentifier'] = identity + '.helper'; helper['CFBundleVersion'] = str(build)
    # Compare semantic values so check mode does not require unrelated plist formatting changes.
    if args.write:
        changes[helper_path] = plistlib.dumps(helper)
    elif plistlib.loads(helper_path.read_bytes()) != helper:
        raise ValueError('helper metadata differs from release identity')
    project_path = root / 'Watt.xcodeproj/project.pbxproj'
    project = json.loads(subprocess.check_output(['/usr/bin/plutil', '-convert', 'json', '-o', '-', str(project_path)]))
    objects = project['objects']; project_text = project_path.read_text()
    targets = {'Watt': '', 'WattHelper': '.helper', 'WattMaintenance': '.maintenance', 'WattHelperInstaller': '.installer', 'WattTests': '.WattTests', 'WattUITests': '.WattUITests'}
    def serial(value):
        if isinstance(value, dict): return '{ ' + ' '.join(json.dumps(k) + ' = ' + serial(v) + ';' for k, v in value.items()) + ' }'
        if isinstance(value, list): return '(' + ''.join(serial(v) + ', ' for v in value) + ')'
        return json.dumps(str(value))
    for target in objects.values():
        if target.get('isa') != 'PBXNativeTarget' or target['name'] not in targets: continue
        for cid in objects[target['buildConfigurationList']]['buildConfigurations']:
            config = objects[cid]; settings = config['buildSettings']
            desired = identity + targets[target['name']]
            if not args.write and settings.get('PRODUCT_BUNDLE_IDENTIFIER') != desired:
                raise ValueError('native target identity differs: ' + target['name'])
            if not args.write and target['name'] in {'Watt', 'WattMaintenance', 'WattHelperInstaller'} and (
                settings.get('CURRENT_PROJECT_VERSION') != str(build) or
                settings.get('INFOPLIST_KEY_CFBundleVersion') != '$(CURRENT_PROJECT_VERSION)'
            ):
                raise ValueError('native target build differs: ' + target['name'])
            if args.write:
                settings['PRODUCT_BUNDLE_IDENTIFIER'] = desired; settings['CURRENT_PROJECT_VERSION'] = str(build)
                if target['name'] == 'Watt': settings['INFOPLIST_KEY_CFBundleVersion'] = '$(CURRENT_PROJECT_VERSION)'
                pattern = r'(?m)^\s*' + cid + r'\s*=\s*\{[^\n]*\};'
                project_text, count = re.subn(pattern, lambda _: '\n\t\t' + cid + ' = ' + serial(config) + ';', project_text)
                if count != 1: raise ValueError('native config serialization boundary missing')
    if args.write: changes[project_path] = project_text.encode()
    daemon_path = root / 'Resources/Helper' / (identity + '.helper.plist')
    refs = [v for v in objects.values() if v.get('isa') == 'PBXFileReference' and str(v.get('path', '')).startswith('Resources/Helper/') and str(v.get('path', '')).endswith('.helper.plist')]
    if len(refs) != 1: raise ValueError('expected one helper daemon resource')
    old_path = root / refs[0]['path']; daemon = plistlib.loads(old_path.read_bytes())
    daemon['Label'] = identity + '.helper'; daemon['MachServices'] = {identity + '.helper': True}
    if args.write:
        changes[daemon_path] = plistlib.dumps(daemon)
        if old_path != daemon_path:
            old_relative = str(old_path.relative_to(root)); new_relative = str(daemon_path.relative_to(root))
            changes[project_path] = changes[project_path].replace(old_relative.encode(), new_relative.encode())
    elif old_path != daemon_path or plistlib.loads(old_path.read_bytes()) != daemon:
        raise ValueError('daemon naming differs from release identity')
    if args.write:
        for path, contents in changes.items(): path.write_bytes(contents)
        if old_path != daemon_path: old_path.unlink()
        (root / 'Resources/ReleaseIdentity.json').write_text(json.dumps(data, sort_keys=True) + '\n')
    elif source_path.read_bytes() != changes[source_path]:
        raise ValueError('compiled identity differs from release identity')
    print('PASS: compiled app/helper identity, daemon naming and native targets match reviewed input')
except (ValueError, KeyError, OSError, json.JSONDecodeError, plistlib.InvalidFileException) as error:
    print('BLOCKED: ' + str(error), file=sys.stderr); sys.exit(1)
