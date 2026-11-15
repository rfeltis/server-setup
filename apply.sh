#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root. It asks for your sudo password." >&2
    exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")"
exec ansible-playbook -i localhost, -c local playbook.yml --ask-become-pass "$@"
