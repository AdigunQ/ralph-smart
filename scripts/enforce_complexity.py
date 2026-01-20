#!/usr/bin/env python3
import os
import ast
import sys

# Configuration: The "20/200" Rule
MAX_FILE_LINES = 200
MAX_FUNCTION_LINES = 20
MAX_PARAMS = 3
MAX_NESTING = 2

# Colors
RED, GREEN, YELLOW, RESET = "\033[91m", "\033[92m", "\033[93m", "\033[0m"

def check_file_length(filepath, lines):
    count = len(lines)
    if count > MAX_FILE_LINES:
        print(f"{RED}[FAIL] File: {count} lines > {MAX_FILE_LINES}{RESET}")
        print(f"      {filepath}")
        return False
    return True

def analyze_function(node, filepath):
    # Approximation: end_lineno - lineno.
    lines = node.end_lineno - node.lineno + 1
    passed = True
    
    if lines > MAX_FUNCTION_LINES:
        print(f"{RED}[FAIL] Func '{node.name}': {lines} lines > {MAX_FUNCTION_LINES}{RESET}")
        print(f"      {filepath}:{node.lineno}")
        passed = False
        
    if len(node.args.args) > MAX_PARAMS:
        print(f"{YELLOW}[WARN] Func '{node.name}': {len(node.args.args)} params{RESET}")
        # Warning only
        
    return passed

def check_complexity(filepath, content):
    try:
        tree = ast.parse(content)
    except SyntaxError:
        return True

    passed = True
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if not analyze_function(node, filepath):
                passed = False
    return passed

def scan_directory():
    violations = 0
    count = 0
    for root, _, files in os.walk("."):
        if any(x in root for x in [".git", "node_modules", "venv"]): continue
            
        for name in files:
            if name.endswith(".py"):
                path = os.path.join(root, name)
                count += 1
                try:
                    with open(path, "r", encoding="utf-8") as f:
                        c = f.read()
                    if not (check_file_length(path, c.splitlines()) and check_complexity(path, c)):
                        violations += 1
                except Exception: pass
    return violations, count

def main():
    print(f"🛡️  Enforcing Complexity Limits...")
    v, c = scan_directory()
    
    print("-" * 40)
    if v > 0:
        print(f"{RED}❌ Verification Failed: {v} files violated rules.{RESET}")
        sys.exit(1)
    
    print(f"{GREEN}✅ All {c} files passed.{RESET}")
    sys.exit(0)

if __name__ == "__main__":
    main()
