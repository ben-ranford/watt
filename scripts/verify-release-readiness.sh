#!/bin/sh
set -eu
exec /usr/bin/env python3 "$(dirname "$0")/verify-release-readiness.py" "$@"
