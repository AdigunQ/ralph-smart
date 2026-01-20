#!/bin/bash

# Goal: Install git hooks to enforce complexity and security rules

HOOKS_DIR=".git/hooks"
PRE_COMMIT="$HOOKS_DIR/pre-commit"

echo "🛡️  Installing Claude Bootstrap Hooks..."

# Create pre-commit hook
cat > "$PRE_COMMIT" << 'EOF'
#!/bin/bash
echo "🛡️  Running Bootstrap Pre-Commit Checks..."

# 1. Enforce Complexity (20/200 Rule)
python3 scripts/enforce_complexity.py
if [ $? -ne 0 ]; then
    echo "❌ Complexity Check Failed. Commit rejected."
    exit 1
fi

# 2. Update Code Index (Ensure index is synonymous with code)
python3 scripts/update_code_index.py
git add CODE_INDEX.md

echo "✅ All Checks Passed."
exit 0
EOF

chmod +x "$PRE_COMMIT"
echo "✅ Pre-commit hook installed."
