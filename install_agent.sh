#!/bin/bash

# Ralph Agent Installer
# Usage: ./install_agent.sh [target_directory]
# If no target directory is provided, installs in the current directory.

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$(pwd)}"

echo "🕵️  Installing Ralph Security Agent into: $TARGET_DIR"

if [ ! -d "$TARGET_DIR/.git" ]; then
    echo "⚠️  Warning: Target directory does not look like a git repository."
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 1. Copy Critical Knowledge & Logic
echo "📦 Injecting Brain (Knowledges, Scripts, Agents)..."
cp -r "$SOURCE_DIR/knowledges" "$TARGET_DIR/"
cp -r "$SOURCE_DIR/.agent" "$TARGET_DIR/"
cp -r "$SOURCE_DIR/scripts" "$TARGET_DIR/"
cp "$SOURCE_DIR/CLAUDE.md" "$TARGET_DIR/"
cp "$SOURCE_DIR/AGENTS.md" "$TARGET_DIR/"
cp "$SOURCE_DIR/loop.sh" "$TARGET_DIR/"
cp "$SOURCE_DIR/PROMPT_plan.md" "$TARGET_DIR/"
cp "$SOURCE_DIR/PROMPT_build.md" "$TARGET_DIR/"

# 2. Setup Scaffolding
echo "🏗️  Scaffolding Project Specs..."
mkdir -p "$TARGET_DIR/_project_specs/features"
mkdir -p "$TARGET_DIR/_project_specs/todos"
mkdir -p "$TARGET_DIR/_project_specs/session"
touch "$TARGET_DIR/_project_specs/todos/active.md"

# 3. Install Hooks
echo "🛡️  Installing Guardrails..."
cd "$TARGET_DIR"
# Ensure scripts are executable
chmod +x scripts/*.sh scripts/*.py

# Run the hook installer
./scripts/install_hooks.sh

# 4. Initialize Index
echo "🧠 Generating Initial Code Index..."
python3 scripts/update_code_index.py

echo ""
echo "✅ Ralph Agent Installed Successfully!"
echo "   - Knowledge Base: ./knowledges/"
echo "   - Workflows:      ./.agent/workflows/"
echo "   - Active Specs:   ./_project_specs/"
echo "   - Guardrails:     Active (Pre-commit)"
echo ""
echo "Try running: /hound or /audit"
