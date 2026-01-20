#!/usr/bin/env python3
import os
import ast
import sys

# Configuration: The "20/200" Rule
MAX_FILE_LINES = 200
MAX_FUNCTION_LINES = 20
MAX_PARAMS = 3
MAX_NESTING = 2

# Colors for output
RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
RESET = "\033[0m"

def check_file_length(filepath, lines):
    count = len(lines)
    if count > MAX_FILE_LINES:
        print(f"{RED}[FAIL] File length: {count} lines > {MAX_FILE_LINES} limit{RESET}")
        print(f"      File: {filepath}")
        return False
    return True

def check_complexity(filepath, content):
    try:
        tree = ast.parse(content)
    except SyntaxError:
        # Not Python code or syntax error, skip AST checks
        return True

    passed = True
    
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            # Check Function Length
            # Approximation: end_lineno - lineno. 
            # Note: Includes docstrings and comments inside, which is strict but safe.
            func_lines = node.end_lineno - node.lineno + 1
            if func_lines > MAX_FUNCTION_LINES:
                print(f"{RED}[FAIL] Function '{node.name}' length: {func_lines} lines > {MAX_FUNCTION_LINES} limit{RESET}")
                print(f"      File: {filepath}:{node.lineno}")
                passed = False
            
            # Check Parameter Count
            param_count = len(node.args.args)
            if param_count > MAX_PARAMS:
                print(f"{YELLOW}[WARN] Function '{node.name}' params: {param_count} > {MAX_PARAMS} limit{RESET}")
                print(f"      File: {filepath}:{node.lineno}")
                # We enforce warnings as failures for strict mode, or just warn. 
                # Let's keep strictness high for "Solidify".
                passed = False

            # Check Nesting Depth
            # TODO: Implement a walker to count max nesting of If/For/While blocks
            
    return passed

def main():
    print(f"🛡️  Enforcing Complexity Limits (20 lines/func, 200 lines/file)...")
    
    violations = 0
    checked_files = 0
    
    for root, _, files in os.walk("."):
        if ".git" in root or "node_modules" in root or "venv" in root:
            continue
            
        for name in files:
            if name.endswith(".py"): # Currently checking Python; extend for others if needed
                filepath = os.path.join(root, name)
                checked_files += 1
                
                try:
                    with open(filepath, "r", encoding="utf-8") as f:
                        content = f.read()
                        lines = content.splitlines()
                        
                    file_ok = check_file_length(filepath, lines)
                    ast_ok = check_complexity(filepath, content)
                    
                    if not file_ok or not ast_ok:
                        violations += 1
                        
                except Exception as e:
                    print(f"{YELLOW}[WARN] Could not parse {filepath}: {e}{RESET}")

    print("-" * 40)
    if violations > 0:
        print(f"{RED}❌ Verification Failed: {violations} files violated complexity rules.{RESET}")
        sys.exit(1)
    else:
        print(f"{GREEN}✅ All {checked_files} files passed complexity checks.{RESET}")
        sys.exit(0)

if __name__ == "__main__":
    main()
