#!/bin/zsh
set -e
export PATH="$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
cd "${0:A:h}"
exec node scripts/agent-launcher.mjs "$@"
