#!/usr/bin/env sh
# identity-guard.sh - enforces expected git author and committer identity

# skip in ci or when husky is disabled
if [ "${CI:-}" = "true" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${GITLAB_CI:-}" ] || [ "${HUSKY:-}" = "0" ]; then
  echo "identity guard skipped in ci or husky=0"
  exit 0
fi

# read the expected identity from local git config (set by bootstrap)
EXPECTED_NAME=$(git config --local atlas.expected-name 2>/dev/null || printf '')
EXPECTED_EMAIL=$(git config --local atlas.expected-email 2>/dev/null || printf '')

if [ -z "$EXPECTED_NAME" ] || [ -z "$EXPECTED_EMAIL" ]; then
  echo "[error] expected identity not configured."
  echo "   run 'bun bs' to bootstrap your environment, or set manually:"
  echo "     git config --local atlas.expected-name \"Your Name\""
  echo "     git config --local atlas.expected-email \"you@example.com\""
  exit 1
fi

# resolve effective author identity (env vars > author.* > user.*)
CONFIG_USER=$(git config user.name 2>/dev/null || printf '')
CONFIG_EMAIL=$(git config user.email 2>/dev/null || printf '')
CONFIG_AUTHOR_USER=$(git config author.name 2>/dev/null || printf '%s' "$CONFIG_USER")
CONFIG_AUTHOR_EMAIL=$(git config author.email 2>/dev/null || printf '%s' "$CONFIG_EMAIL")
EFFECTIVE_USER="${GIT_AUTHOR_NAME:-$CONFIG_AUTHOR_USER}"
EFFECTIVE_EMAIL="${GIT_AUTHOR_EMAIL:-$CONFIG_AUTHOR_EMAIL}"

# resolve effective committer identity through git (GIT_COMMITTER_* > committer.* > user.*)
COMMITTER_IDENT=$(git var GIT_COMMITTER_IDENT 2>/dev/null || true)
if [ -n "$COMMITTER_IDENT" ]; then
  EFFECTIVE_COMMITTER_USER="${COMMITTER_IDENT%% <*}"
  _ident_rest="${COMMITTER_IDENT#*<}"
  EFFECTIVE_COMMITTER_EMAIL="${_ident_rest%%>*}"
else
  CONFIG_COMMITTER_USER=$(git config committer.name 2>/dev/null || printf '%s' "$CONFIG_USER")
  CONFIG_COMMITTER_EMAIL=$(git config committer.email 2>/dev/null || printf '%s' "$CONFIG_EMAIL")
  EFFECTIVE_COMMITTER_USER="${GIT_COMMITTER_NAME:-$CONFIG_COMMITTER_USER}"
  EFFECTIVE_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$CONFIG_COMMITTER_EMAIL}"
fi

if [ "$EFFECTIVE_USER" != "$EXPECTED_NAME" ] || [ "$EFFECTIVE_EMAIL" != "$EXPECTED_EMAIL" ]; then
  echo "[error] git author identity mismatch!"
  echo "   expected:  $EXPECTED_NAME <$EXPECTED_EMAIL>"
  echo "   effective: $EFFECTIVE_USER <$EFFECTIVE_EMAIL>"
  if [ -n "${GIT_AUTHOR_NAME:-}" ] || [ -n "${GIT_AUTHOR_EMAIL:-}" ]; then
    echo "   (GIT_AUTHOR_NAME/EMAIL env vars are overriding git config - unset them first)"
    echo "     unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL"
  fi
  echo ""
  echo "to fix, run 'bun bs' or set your identity:"
  echo "   git config user.name \"$EXPECTED_NAME\""
  echo "   git config user.email \"$EXPECTED_EMAIL\""
  echo ""
  exit 1
fi

if [ "$EFFECTIVE_COMMITTER_USER" != "$EXPECTED_NAME" ] || [ "$EFFECTIVE_COMMITTER_EMAIL" != "$EXPECTED_EMAIL" ]; then
  echo "[error] git committer identity mismatch!"
  echo "   expected:  $EXPECTED_NAME <$EXPECTED_EMAIL>"
  echo "   committer: $EFFECTIVE_COMMITTER_USER <$EFFECTIVE_COMMITTER_EMAIL>"
  if [ -n "${GIT_COMMITTER_NAME:-}" ] || [ -n "${GIT_COMMITTER_EMAIL:-}" ]; then
    echo "   (GIT_COMMITTER_NAME/EMAIL env vars are overriding git config - unset them first)"
    echo "     unset GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL"
  fi
  echo ""
  echo "to fix, run 'bun bs' or align user/committer config:"
  echo "   git config user.name \"$EXPECTED_NAME\""
  echo "   git config user.email \"$EXPECTED_EMAIL\""
  echo "   git config --unset-all committer.name 2>/dev/null || true"
  echo "   git config --unset-all committer.email 2>/dev/null || true"
  echo ""
  exit 1
fi

exit 0