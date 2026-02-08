#!/usr/bin/env python3
"""
Complexity Enforcement Script for Ralph Security Agent
Enforces the "20/200" rule and additional security-focused complexity metrics
"""

import os
import ast
import sys
import re
from pathlib import Path
from typing import List, Tuple, Optional

# Configuration: The "20/200" Rule
MAX_FILE_LINES = 200
MAX_FUNCTION_LINES = 20
MAX_PARAMS = 4
MAX_NESTING = 3
MAX_STATE_VARIABLES = 15
MAX_EXTERNAL_CALLS = 5

# Colors
RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
RESET = "\033[0m"


class SecurityComplexityChecker(ast.NodeVisitor):
    """AST visitor to check for security-relevant complexity metrics"""
    
    def __init__(self, filepath: str):
        self.filepath = filepath
        self.violations = []
        self.current_function = None
        self.external_calls = 0
        self.state_modifications = 0
        self.require_statements = 0
        
    def visit_FunctionDef(self, node):
        """Analyze function definition"""
        old_function = self.current_function
        old_external_calls = self.external_calls
        old_state_mods = self.state_modifications
        old_requires = self.require_statements
        
        self.current_function = node.name
        self.external_calls = 0
        self.state_modifications = 0
        self.require_statements = 0
        
        # Check function length
        lines = node.end_lineno - node.lineno + 1
        if lines > MAX_FUNCTION_LINES:
            self.violations.append({
                'type': 'function_length',
                'name': node.name,
                'value': lines,
                'limit': MAX_FUNCTION_LINES,
                'line': node.lineno,
                'severity': 'error'
            })
        
        # Check parameter count
        param_count = len(node.args.args) + len(node.args.kwonlyargs)
        if node.args.vararg:
            param_count += 1
        if node.args.kwarg:
            param_count += 1
            
        if param_count > MAX_PARAMS:
            self.violations.append({
                'type': 'parameter_count',
                'name': node.name,
                'value': param_count,
                'limit': MAX_PARAMS,
                'line': node.lineno,
                'severity': 'warning'
            })
        
        # Check nesting depth
        max_nesting = self._get_max_nesting(node)
        if max_nesting > MAX_NESTING:
            self.violations.append({
                'type': 'nesting_depth',
                'name': node.name,
                'value': max_nesting,
                'limit': MAX_NESTING,
                'line': node.lineno,
                'severity': 'warning'
            })
        
        # Continue visiting
        self.generic_visit(node)
        
        # Check for unprotected external calls (simulated for Python)
        if self.external_calls > MAX_EXTERNAL_CALLS:
            self.violations.append({
                'type': 'external_calls',
                'name': node.name,
                'value': self.external_calls,
                'limit': MAX_EXTERNAL_CALLS,
                'line': node.lineno,
                'severity': 'warning'
            })
        
        # Security: Functions with state modifications should have requires
        if self.state_modifications > 0 and self.require_statements == 0:
            self.violations.append({
                'type': 'missing_validation',
                'name': node.name,
                'value': self.state_modifications,
                'line': node.lineno,
                'severity': 'warning',
                'message': 'Function modifies state but has no validation checks'
            })
        
        # Restore context
        self.current_function = old_function
        self.external_calls = old_external_calls
        self.state_modifications = old_state_mods
        self.require_statements = old_requires
    
    def visit_Call(self, node):
        """Detect external calls and validation"""
        if isinstance(node.func, ast.Name):
            if node.func.id in ['open', 'requests', 'urllib', 'httpx']:
                self.external_calls += 1
            if node.func.id in ['assert', 'raise']:
                self.require_statements += 1
        self.generic_visit(node)
    
    def visit_Assign(self, node):
        """Detect state modifications"""
        self.state_modifications += 1
        self.generic_visit(node)
    
    def _get_max_nesting(self, node) -> int:
        """Calculate maximum nesting depth"""
        max_depth = 0
        
        for child in ast.walk(node):
            if isinstance(child, (ast.If, ast.For, ast.While, ast.With, ast.Try)):
                depth = self._calculate_depth(node, child)
                max_depth = max(max_depth, depth)
        
        return max_depth
    
    def _calculate_depth(self, root, target) -> int:
        """Calculate depth of target node within root"""
        # Simplified depth calculation
        depth = 0
        for node in ast.walk(root):
            if node is target:
                return depth
            if isinstance(node, (ast.If, ast.For, ast.While)):
                depth += 1
        return depth


def check_file_length(filepath: str, lines: List[str]) -> Tuple[bool, Optional[dict]]:
    """Check if file exceeds maximum line count"""
    count = len(lines)
    if count > MAX_FILE_LINES:
        return False, {
            'type': 'file_length',
            'filepath': filepath,
            'value': count,
            'limit': MAX_FILE_LINES,
            'severity': 'error'
        }
    return True, None


def analyze_solidity_file(filepath: str, content: str) -> List[dict]:
    """Analyze Solidity file for complexity and security issues"""
    violations = []
    lines = content.splitlines()
    
    # File length check
    if len(lines) > MAX_FILE_LINES:
        violations.append({
            'type': 'file_length',
            'filepath': filepath,
            'value': len(lines),
            'limit': MAX_FILE_LINES,
            'severity': 'error'
        })
    
    # Count state variables
    state_var_pattern = r'^\s*(uint|int|address|bool|mapping|struct|enum)\s+(\w+)\s*;'
    state_vars = re.findall(state_var_pattern, content, re.MULTILINE)
    if len(state_vars) > MAX_STATE_VARIABLES:
        violations.append({
            'type': 'state_variables',
            'filepath': filepath,
            'value': len(state_vars),
            'limit': MAX_STATE_VARIABLES,
            'severity': 'warning',
            'message': f'Too many state variables ({len(state_vars)})'
        })
    
    # Count external calls
    external_patterns = [
        r'\.call\{value:',
        r'\.delegatecall',
        r'\.staticcall',
        r'\.transfer\(',
        r'\.send\(',
    ]
    external_calls = sum(
        len(re.findall(pattern, content))
        for pattern in external_patterns
    )
    
    if external_calls > MAX_EXTERNAL_CALLS:
        violations.append({
            'type': 'external_calls',
            'filepath': filepath,
            'value': external_calls,
            'limit': MAX_EXTERNAL_CALLS,
            'severity': 'warning',
            'message': f'Many external calls ({external_calls}), check reentrancy protection'
        })
    
    # Check for reentrancy guard on functions with external calls
    if external_calls > 0:
        has_reentrancy_guard = 'nonReentrant' in content or 'ReentrancyGuard' in content
        if not has_reentrancy_guard:
            violations.append({
                'type': 'missing_reentrancy_guard',
                'filepath': filepath,
                'severity': 'warning',
                'message': 'External calls without reentrancy guard'
            })
    
    return violations


def check_file(filepath: str) -> List[dict]:
    """Check a single file for complexity violations"""
    violations = []
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            lines = content.splitlines()
    except Exception as e:
        return [{
            'type': 'read_error',
            'filepath': filepath,
            'message': str(e),
            'severity': 'error'
        }]
    
    # Check file length
    passed, violation = check_file_length(filepath, lines)
    if not passed:
        violations.append(violation)
    
    # Language-specific analysis
    if filepath.endswith('.py'):
        try:
            tree = ast.parse(content)
            checker = SecurityComplexityChecker(filepath)
            checker.visit(tree)
            violations.extend(checker.violations)
        except SyntaxError:
            pass  # Skip files with syntax errors
    
    elif filepath.endswith('.sol'):
        violations.extend(analyze_solidity_file(filepath, content))
    
    return violations


def scan_directory(directory: str = '.') -> Tuple[int, int, List[dict]]:
    """Scan directory for complexity violations"""
    all_violations = []
    file_count = 0
    error_count = 0
    
    skip_dirs = {'.git', 'node_modules', 'venv', '.venv', '__pycache__', 'target'}
    extensions = {'.py', '.sol', '.js', '.ts'}
    
    for root, dirs, files in os.walk(directory):
        # Skip certain directories
        dirs[:] = [d for d in dirs if d not in skip_dirs]
        
        for name in files:
            ext = os.path.splitext(name)[1]
            if ext in extensions:
                filepath = os.path.join(root, name)
                file_count += 1
                
                violations = check_file(filepath)
                if violations:
                    error_count += len([v for v in violations if v.get('severity') == 'error'])
                    all_violations.extend(violations)
    
    return file_count, error_count, all_violations


def print_violations(violations: List[dict]):
    """Print violations in a readable format"""
    errors = [v for v in violations if v.get('severity') == 'error']
    warnings = [v for v in violations if v.get('severity') == 'warning']
    
    if errors:
        print(f"\n{RED}ERRORS ({len(errors)}):{RESET}")
        for v in errors:
            if 'filepath' in v:
                print(f"  {RED}✗{RESET} {v['filepath']}")
            if 'name' in v:
                print(f"      Function: {v['name']}")
            print(f"      {v.get('type', 'error').replace('_', ' ').title()}: "
                  f"{v.get('value', 'N/A')} (limit: {v.get('limit', 'N/A')})")
            if 'message' in v:
                print(f"      Message: {v['message']}")
            if 'line' in v:
                print(f"      Line: {v['line']}")
    
    if warnings:
        print(f"\n{YELLOW}WARNINGS ({len(warnings)}):{RESET}")
        for v in warnings:
            if 'filepath' in v:
                print(f"  {YELLOW}⚠{RESET} {v['filepath']}")
            if 'name' in v:
                print(f"      Function: {v['name']}")
            print(f"      {v.get('type', 'warning').replace('_', ' ').title()}")
            if 'message' in v:
                print(f"      Message: {v['message']}")
            if 'value' in v and 'limit' in v:
                print(f"      Value: {v['value']} (limit: {v['limit']})")


def main():
    """Main entry point"""
    print(f"{BLUE}🔍 Ralph Security Complexity Analysis{RESET}")
    print(f"{BLUE}═════════════════════════════════════{RESET}")
    print(f"Rules:")
    print(f"  • Max file length: {MAX_FILE_LINES} lines")
    print(f"  • Max function length: {MAX_FUNCTION_LINES} lines")
    print(f"  • Max parameters: {MAX_PARAMS}")
    print(f"  • Max nesting depth: {MAX_NESTING}")
    print(f"  • Max state variables: {MAX_STATE_VARIABLES}")
    print(f"  • Max external calls per file: {MAX_EXTERNAL_CALLS}")
    print()
    
    file_count, error_count, violations = scan_directory()
    
    if violations:
        print_violations(violations)
    
    print(f"\n{BLUE}═════════════════════════════════════{RESET}")
    print(f"Files analyzed: {file_count}")
    print(f"Total violations: {len(violations)}")
    print(f"Errors: {error_count}")
    print(f"Warnings: {len(violations) - error_count}")
    
    if error_count > 0:
        print(f"\n{RED}❌ Verification Failed: {error_count} errors found{RESET}")
        sys.exit(1)
    elif violations:
        print(f"\n{YELLOW}⚠️  Verification Passed with {len(violations)} warnings{RESET}")
        sys.exit(0)
    else:
        print(f"\n{GREEN}✅ All {file_count} files passed complexity checks{RESET}")
        sys.exit(0)


if __name__ == "__main__":
    main()
