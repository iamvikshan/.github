#!/usr/bin/env sh
# sentry.sh - enforces expected git author and committer identity

# skip in ci or when husky is disabled
if [ "${CI:-}" = "true" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${GITLAB_CI:-}" ] || [ "${HUSKY:-}" = "0" ]; then
  echo "identity guard skipped in ci or husky=0"
  exit 0
fi

# read the expected identity from local git config (set by bootstrap)
EXPECTED_NAME=$(git config --local expected-name 2>/dev/null || printf '')
EXPECTED_EMAIL=$(git config --local expected-email 2>/dev/null || printf '')

if [ -z "$EXPECTED_NAME" ] || [ -z "$EXPECTED_EMAIL" ]; then
  echo "[error] expected identity not configured."
  echo "   run 'bun bs' to bootstrap your environment, or set manually:"
  echo "     git config --local expected-name \"Your Name\""
  echo "     git config --local expected-email \"you@example.com\""
  exit 1
fi

# A set-but-empty override needs an actionable diagnostic, even when git var accepts it.
for identity_var in GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL; do
  eval 'identity_set=${'"$identity_var"'+set}'
  eval 'identity_value=${'"$identity_var"'-}'
  if [ "$identity_set" = set ] && [ -z "$identity_value" ]; then
    echo "[error] $identity_var is set but empty."
    echo "   unset it first: unset $identity_var"
    exit 1
  fi
done

# Let Git resolve and validate both identities, including environment overrides.
if ! AUTHOR_IDENT=$(git var GIT_AUTHOR_IDENT 2>/dev/null); then
  echo "[error] git cannot resolve a valid author identity."
  echo "   check user/author config and GIT_AUTHOR_NAME/EMAIL."
  exit 1
fi
if ! COMMITTER_IDENT=$(git var GIT_COMMITTER_IDENT 2>/dev/null); then
  echo "[error] git cannot resolve a valid committer identity."
  echo "   check user/committer config and GIT_COMMITTER_NAME/EMAIL."
  exit 1
fi
EFFECTIVE_USER="${AUTHOR_IDENT%% <*}"
_ident_rest="${AUTHOR_IDENT#*<}"
EFFECTIVE_EMAIL="${_ident_rest%%>*}"
EFFECTIVE_COMMITTER_USER="${COMMITTER_IDENT%% <*}"
_ident_rest="${COMMITTER_IDENT#*<}"
EFFECTIVE_COMMITTER_EMAIL="${_ident_rest%%>*}"

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
  echo "   git config --local --replace-all committer.name \"$EXPECTED_NAME\""
  echo "   git config --local --replace-all committer.email \"$EXPECTED_EMAIL\""
  echo ""
  exit 1
fi

exit 0