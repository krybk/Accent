#!/usr/bin/env bash
#
# Guard against a secret landing in the repository.
#
# The repository is public, and that changes the cost of a mistake: a leaked
# gateway token is root on a server, and a leaked keystore is the ability to
# sign someone else's APK with our key. So this check runs in CI and fails the
# build rather than warning.
#
# What it cannot do: find a secret that looks like no known format. That is what
# .gitignore and the "secrets are generated on the target machine" rule are for.
# This script is the last net, not the first line.
set -euo pipefail

cd "$(dirname "$0")/.."

status=0

# Known key formats, one per line: <label>|<ERE pattern>. The patterns are
# written so they do not match themselves when this file is scanned — otherwise
# the check would fail on its own source.
while IFS='|' read -r label pattern; do
  [ -z "$label" ] && continue
  # git ls-files rather than a recursive grep: we check what will actually enter
  # history, and we do not trip over node_modules or target.
  if hits=$(git ls-files -z \
    | xargs -0 grep -nIE "$pattern" 2>/dev/null); then
    echo "Secret found ($label):"
    echo "$hits"
    status=1
  fi
done <<'PATTERNS'
OpenRouter|sk-or-v1-[0-9a-f]{40,}
Anthropic|sk-ant-[A-Za-z0-9_-]{24,}
OpenAI|sk-(proj|svcacct)-[A-Za-z0-9_-]{24,}
Google|AIza[0-9A-Za-z_-]{35}
AWS|AKIA[0-9A-Z]{16}
PEM private key|-----BEGIN [A-Z ]*PRIVATE KEY-----
PATTERNS

# Files that must never be in history under any name. This list mirrors the
# secret half of .gitignore; the two must not drift apart.
forbidden='(^|/)(\.env(\..*)?|id_ed25519|id_rsa|authorized_keys|key\.properties)$|\.(pem|jks|keystore)$'
if tracked=$(git ls-files | grep -E "$forbidden" | grep -v '\.env\.example$'); then
  echo "Tracked files that must not be versioned:"
  echo "$tracked"
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "No secrets found."
fi

exit "$status"
