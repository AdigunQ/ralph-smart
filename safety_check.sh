#!/bin/bash

# safety_check.sh - The "Hook" that prevents dangerous actions
# Exits with 1 (fail) if a dangerous pattern is detected in the input command/code.

INPUT_CONTENT=$1

# 1. Define Dangerous Patterns (The Blacklist)
DENY_PATTERNS=(
  "rm -rf /"
  "rm -rf ~"
  "export PRIVATE_KEY"
  "cat /etc/shadow"
  "id_rsa"
  ".env"
  "git push force"
  "mkfs"
  "dd if="
)

# 2. Check for patterns
for pattern in "${DENY_PATTERNS[@]}"; do
  if echo "$INPUT_CONTENT" | grep -Fq "$pattern"; then
    echo "🚨 SAFETY HOOK TRIGGERED: Dangerous pattern detected: '$pattern'"
    echo "Action blocked."
    exit 1
  fi
done

# 3. Flow State Approval
# If no dangerous patterns, silently approve (Flow State)
exit 0
