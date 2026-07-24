#!/bin/bash
# identity-guard.sh - Enforces expected git identity to prevent accidental commits

# Skip in CI or when HUSKY is disabled
if [ "${CI:-}" = "true" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${GITLAB_CI:-}" ] || [ "${HUSKY:-}" = "0" ]; then
  echo "Identity guard skipped in CI or HUSKY=0"
  exit 0
fi

# Read the expected identity from local git config (set by bootstrap)
EXPECTED_NAME=$(git config --local atlas.expected-name 2>/dev/null || echo "")
EXPECTED_EMAIL=$(git config --local atlas.expected-email 2>/dev/null || echo "")

if [ -z "$EXPECTED_NAME" ] || [ -z "$EXPECTED_EMAIL" ]; then
  echo "❌ Error: Expected identity not configured."
  echo "   Run 'bun bs' to bootstrap your environment, or set manually:"
  echo "     git config --local atlas.expected-name \"Your Name\""
  echo "     git config --local atlas.expected-email \"you@example.com\""
  exit 1
fi

# Resolve effective author identity (local config > global config > env vars)
# git config without --global returns local first, then global
CONFIG_USER=$(git config user.name 2>/dev/null || echo "")
CONFIG_EMAIL=$(git config user.email 2>/dev/null || echo "")
EFFECTIVE_USER="${GIT_AUTHOR_NAME:-$CONFIG_USER}"
EFFECTIVE_EMAIL="${GIT_AUTHOR_EMAIL:-$CONFIG_EMAIL}"

# Resolve effective committer identity
EFFECTIVE_COMMITTER_USER="${GIT_COMMITTER_NAME:-$EFFECTIVE_USER}"
EFFECTIVE_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$EFFECTIVE_EMAIL}"

if [ "$EFFECTIVE_USER" != "$EXPECTED_NAME" ] || [ "$EFFECTIVE_EMAIL" != "$EXPECTED_EMAIL" ]; then
  echo "❌ Git identity mismatch!"
  echo "   Expected:  $EXPECTED_NAME <$EXPECTED_EMAIL>"
  echo "   Effective: $EFFECTIVE_USER <$EFFECTIVE_EMAIL>"
  if [ -n "${GIT_AUTHOR_NAME:-}" ] || [ -n "${GIT_AUTHOR_EMAIL:-}" ]; then
    echo "   (GIT_AUTHOR_NAME/EMAIL env vars are overriding git config)"
  fi
  echo ""
  echo "To fix, run 'bun bs' or set your identity:"
  echo "   git config user.name \"$EXPECTED_NAME\""
  echo "   git config user.email \"$EXPECTED_EMAIL\""
  echo ""
  exit 1
fi

if [ "$EFFECTIVE_COMMITTER_USER" != "$EXPECTED_NAME" ] || [ "$EFFECTIVE_COMMITTER_EMAIL" != "$EXPECTED_EMAIL" ]; then
  echo "❌ Git committer identity mismatch!"
  echo "   Expected:  $EXPECTED_NAME <$EXPECTED_EMAIL>"
  echo "   Committer: $EFFECTIVE_COMMITTER_USER <$EFFECTIVE_COMMITTER_EMAIL>"
  if [ -n "${GIT_COMMITTER_NAME:-}" ] || [ -n "${GIT_COMMITTER_EMAIL:-}" ]; then
    echo "   (GIT_COMMITTER_NAME/EMAIL env vars are overriding git config)"
  fi
  echo ""
  echo "To fix, run 'bun bs' or set your identity:"
  echo "   git config user.name \"$EXPECTED_NAME\""
  echo "   git config user.email \"$EXPECTED_EMAIL\""
  echo ""
  exit 1
fi

exit 0
