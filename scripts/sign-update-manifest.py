#!/usr/bin/env python3
"""Sign a Watt update manifest with the Ed25519 key in WATT_UPDATE_SIGNING_KEY.

The secret is base64 of a PKCS#8 PEM (openssl genpkey -algorithm ED25519).
It is read from the environment, never from argv. The payload bytes match
JSONEncoder().encode(UpdateManifest), and the output matches SignedUpdate.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_lib


def _pem_from_env(directory: Path) -> Path:
    encoded = os.environ.get('WATT_UPDATE_SIGNING_KEY', '')
    if encoded.strip() == '':
        raise release_lib.ReleaseError('WATT_UPDATE_SIGNING_KEY is not set')
    path = directory / 'update-key.pem'
    release_lib.decode_base64_env(encoded, path)
    if b'BEGIN' not in path.read_bytes():
        raise release_lib.ReleaseError('WATT_UPDATE_SIGNING_KEY must be base64 of a PEM private key')
    return path


def _openssl(arguments: list[str]) -> bytes:
    result = subprocess.run(arguments, check=False, capture_output=True)
    if result.returncode != 0:
        raise release_lib.ReleaseError('openssl refused the update signing key')
    return result.stdout


def public_key_base64(pem: Path) -> str:
    der = _openssl(['openssl', 'pkey', '-in', str(pem), '-pubout', '-outform', 'DER'])
    raw = release_lib.raw_ed25519_public_key(der)
    import base64
    return base64.b64encode(raw).decode('ascii')


def sign_payload(pem: Path, payload: bytes, directory: Path) -> bytes:
    payload_path = directory / 'payload.json'
    signature_path = directory / 'signature.bin'
    public_path = directory / 'public.pem'
    payload_path.write_bytes(payload)
    _openssl(['openssl', 'pkeyutl', '-sign', '-inkey', str(pem), '-rawin', '-in', str(payload_path), '-out', str(signature_path)])
    _openssl(['openssl', 'pkey', '-in', str(pem), '-pubout', '-out', str(public_path)])
    verify = subprocess.run(
        ['openssl', 'pkeyutl', '-verify', '-pubin', '-inkey', str(public_path), '-rawin', '-in', str(payload_path), '-sigfile', str(signature_path)],
        check=False,
        capture_output=True,
    )
    if verify.returncode != 0:
        raise release_lib.ReleaseError('Ed25519 signature did not verify')
    signature = signature_path.read_bytes()
    if len(signature) != 64:
        raise release_lib.ReleaseError('Ed25519 signature must be 64 bytes')
    return signature


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--public-key-out', type=Path, help='write the raw 32-byte public key as base64')
    parser.add_argument('--archive', type=Path, help='ustar artifact whose sha256 is signed')
    parser.add_argument('--identity')
    parser.add_argument('--build')
    parser.add_argument('--minimum-system-version')
    parser.add_argument('--output', type=Path, help='SignedUpdate JSON path')
    args = parser.parse_args()
    if args.public_key_out is None and args.output is None:
        parser.error('pass --public-key-out, --output, or both')
    if args.output is not None and None in (args.archive, args.identity, args.build, args.minimum_system_version):
        parser.error('--output requires --archive, --identity, --build, and --minimum-system-version')
    try:
        with tempfile.TemporaryDirectory(prefix='watt-update-sign-') as temporary:
            directory = Path(temporary)
            pem = _pem_from_env(directory)
            if args.public_key_out is not None:
                args.public_key_out.write_text(public_key_base64(pem) + '\n')
                args.public_key_out.chmod(0o600)
            if args.output is not None:
                digest = release_lib.sha256_file(args.archive)
                payload = release_lib.manifest_payload(args.identity, int(args.build), digest, args.minimum_system_version)
                signature = sign_payload(pem, payload, directory)
                args.output.write_bytes(release_lib.signed_update_document(payload, signature) + b'\n')
                print('Signed update manifest for build', args.build)
    except (release_lib.ReleaseError, OSError, subprocess.CalledProcessError, ValueError) as error:
        print('BLOCKED: ' + str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
