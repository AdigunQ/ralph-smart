#!/bin/bash

###############################################################################
# Safety Check Hook - Prevents dangerous operations
# This script acts as a guardrail to prevent accidental or malicious actions
###############################################################################

INPUT_CONTENT="$1"
EXIT_CODE=0

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to log blocked operations
log_blocked() {
    echo -e "${RED}🚨 SAFETY HOOK TRIGGERED${NC}"
    echo -e "${RED}   Pattern: $1${NC}"
    echo -e "${RED}   Action blocked for security.${NC}"
    echo ""
    echo "If you believe this is a false positive:"
    echo "  1. Review the command carefully"
    echo "  2. Consider if there's a safer alternative"
    echo "  3. If necessary, bypass manually with caution"
}

# Function to log warnings
log_warning() {
    echo -e "${YELLOW}⚠️  SAFETY WARNING${NC}"
    echo -e "${YELLOW}   Pattern: $1${NC}"
    echo -e "${YELLOW}   Review carefully before proceeding.${NC}"
}

###############################################################################
# DENY PATTERNS - These operations are blocked
###############################################################################

# Category 1: Destructive filesystem operations
deny_patterns[
    "rm -rf /"           # Delete root filesystem
    "rm -rf ~"           # Delete home directory
    "rm -rf /home"       # Delete home directories
    "rm -rf /*"          # Delete all files
    "mkfs"               # Format filesystem
    "dd if="             # Direct disk write
    "> /dev/sda"          # Write to disk device
    "format"             # Format operations
]

# Category 2: Git dangerous operations
deny_patterns[
    "git push --force"   # Force push
    "git push -f"        # Force push (short)
    "git reset --hard"   # Hard reset
    "git clean -fd"      # Force clean
]

# Category 3: Credential exposure
deny_patterns[
    "export PRIVATE_KEY" # Exposing private key
    "export MNEMONIC"    # Exposing mnemonic
    "export API_KEY"     # Exposing API key
    "export PASSWORD"    # Exposing password
    "export SECRET"      # Exposing secret
    "cat.*id_rsa"        # Reading SSH key
    "cat.*.env"          # Reading env file
    "cat /etc/shadow"    # Reading password hashes
    "cat /etc/passwd"    # Reading user database
]

# Category 5: Network security
deny_patterns[
    "nc -l"              # Netcat listener
    "ncat -l"            # Ncat listener
    "nc -e"              # Netcat with execution
    "iptables -F"        # Flush firewall rules
]

# Category 6: Privilege escalation
deny_patterns[
    "chmod 777 /"        # World-writable root
    "chmod -R 777 /"     # Recursive world-writable
    "chown root"         # Change to root ownership
]

# Check deny patterns
for pattern in "${deny_patterns[@]}"; do
    if echo "$INPUT_CONTENT" | grep -Eq "$pattern"; then
        log_blocked "$pattern"
        exit 1
    fi
done

###############################################################################
# WARNING PATTERNS - These operations trigger warnings but aren't blocked
###############################################################################

# Category 7: Potentially risky operations
warn_patterns[
    "rm -rf"             # Recursive delete (not root)
    "DROP TABLE"         # Database table drop
    "DELETE FROM"        # Database delete
    "UPDATE.*WHERE"      # Database update (check WHERE clause)
    "curl.*| sh"         # Pipe curl to shell
    "curl.*| bash"       # Pipe curl to bash
    "wget.*| sh"         # Pipe wget to shell
    "wget.*| bash"       # Pipe wget to bash
    "eval("              # Eval usage
    "exec("              # Exec usage
    "os.system"          # System command in Python
    "subprocess.call"    # Subprocess in Python
    "child_process"      # Child process in Node.js
]

# Check warning patterns
for pattern in "${warn_patterns[@]}"; do
    if echo "$INPUT_CONTENT" | grep -Eq "$pattern"; then
        log_warning "$pattern"
        # Don't exit, just warn
        EXIT_CODE=0
    fi
done

###############################################################################
# SMART CONTRACT SPECIFIC CHECKS
###############################################################################

# Check for dangerous Solidity operations
solidity_dangerous[
    "selfdestruct"       # Contract destruction
    "delegatecall"       # Delegatecall (if not whitelisted)
    "callcode"           # Deprecated callcode
    "assembly"           # Inline assembly
]

for pattern in "${solidity_dangerous[@]}"; do
    if echo "$INPUT_CONTENT" | grep -Eq "$pattern"; then
        echo -e "${YELLOW}⚠️  SOLIDITY WARNING${NC}"
        echo -e "${YELLOW}   Dangerous operation: $pattern${NC}"
        echo -e "${YELLOW}   Review for security implications.${NC}"
    fi
done

###############################################################################
# ALLOWED PATTERNS - Explicitly safe operations
###############################################################################

# These patterns are always allowed
allowed_patterns[
    "^mkdir"
    "^touch"
    "^cat.*\.md$"
    "^ls"
    "^pwd"
    "^echo"
    "^grep"
    "^forge"
    "^hardhat"
    "^npm"
    "^yarn"
    "^git status"
    "^git log"
    "^git diff"
    "^git branch"
    "^git checkout"
    "^git add"
    "^git commit"
    "^git pull"
    "^python"
    "^node"
]

###############################################################################
# FLOW STATE APPROVAL
###############################################################################

# If we get here, no dangerous patterns were detected
echo -e "${GREEN}✓ Safety check passed${NC}"
exit 0
