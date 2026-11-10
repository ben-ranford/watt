#!/usr/bin/env python3
"""Run a command and exit 124 if it exceeds a wall-clock limit.

The command starts in its own session so a hang can be signalled as a group.
Any other status is the command's own status. Exit 127 means the command was
not found.
"""

from __future__ import annotations

import argparse
import os
import signal
import subprocess
import sys


def positive_int(value: str) -> int:
    if not value.isdigit() or int(value) < 1:
        raise argparse.ArgumentTypeError('must be a positive integer')
    return int(value)


def terminate(proc: subprocess.Popen[bytes]) -> None:
    if proc.poll() is not None:
        return
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    try:
        proc.wait(timeout=5)
        return
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        return
    proc.wait(timeout=5)


def run_command(seconds: int, command: list[str]) -> int:
    try:
        proc = subprocess.Popen(command, start_new_session=True)
    except FileNotFoundError:
        print('BLOCKED: command not found: ' + command[0], file=sys.stderr)
        return 127
    try:
        return proc.wait(timeout=seconds)
    except subprocess.TimeoutExpired:
        if proc.poll() is not None:
            return proc.returncode or 0
        terminate(proc)
        return 124


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seconds', required=True, type=positive_int)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command[:1] == ['--']:
        command = command[1:]
    if not command:
        print('BLOCKED: missing command', file=sys.stderr)
        sys.exit(2)
    sys.exit(run_command(args.seconds, command))


if __name__ == '__main__':
    main()
