#!/bin/bash

# Goal: Install git hooks to enforce complexity and security rules
set -euo pipefail

HOOKS_DIR=".git/hooks"
PRE_COMMIT="$HOOKS_DIR/pre-commit"

echo "🛡️  Installing Claude Bootstrap Hooks..."

# Create pre-commit hook
cat > "$PRE_COMMIT" << 'EOF'
#!/bin/bash
set -euo pipefail

echo "🛡️  Running Bootstrap Pre-Commit Checks..."

# 1. Enforce Complexity (20/200 Rule)
python3 scripts/enforce_complexity.py

# 2. Update Code Index (Ensure index is synonymous with code)
python3 scripts/update_code_index.py
git add CODE_INDEX.md

# 3. v2 lint for changed task artifacts
STAGED_PATHS="$(git diff --cached --name-only --diff-filter=ACMR)"
if [ -n "$STAGED_PATHS" ]; then
  # shellcheck disable=SC2086
  scripts/lint_v2_tasks_from_paths.sh $STAGED_PATHS
fi

echo "✅ All Checks Passed."
exit 0
EOF

chmod +x "$PRE_COMMIT"
echo "✅ Pre-commit hook installed."
