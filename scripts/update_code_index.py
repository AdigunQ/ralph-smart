#!/usr/bin/env python3
"""
Code Index Generator for Ralph Security Agent
Creates a searchable index of all functions, contracts, and capabilities
"""

import argparse
import os
import ast
import re
from pathlib import Path
from typing import List, Dict, Optional, Any
from dataclasses import dataclass

DEFAULT_INDEX_FILE = "CODE_INDEX.md"
IGNORE_PATTERNS = {
    ".git", "node_modules", "venv", ".venv", "__pycache__",
    "findings", "codeql-db", ".agent"
}


@dataclass
class CodeEntry:
    """Represents a code entry for indexing"""
    name: str
    file_path: str
    line_number: int
    entry_type: str  # function, contract, modifier, event, etc.
    description: str
    params: str
    visibility: str = ""  # public, private, external, internal
    modifiers: str = ""


class PythonAnalyzer:
    """Analyze Python files"""
    
    @staticmethod
    def analyze(filepath: str) -> List[CodeEntry]:
        entries = []
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                tree = ast.parse(content)
        except Exception:
            return entries
        
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef):
                doc = ast.get_docstring(node) or "No description"
                desc = doc.split('\n')[0][:60]
                params = ', '.join([a.arg for a in node.args.args])
                
                entries.append(CodeEntry(
                    name=node.name,
                    file_path=filepath,
                    line_number=node.lineno,
                    entry_type="function",
                    description=desc,
                    params=f"({params})"
                ))
            
            elif isinstance(node, ast.ClassDef):
                doc = ast.get_docstring(node) or "No description"
                desc = doc.split('\n')[0][:60]
                
                entries.append(CodeEntry(
                    name=node.name,
                    file_path=filepath,
                    line_number=node.lineno,
                    entry_type="class",
                    description=desc,
                    params=""
                ))
        
        return entries


class SolidityAnalyzer:
    """Analyze Solidity files"""
    
    # Regex patterns for Solidity parsing
    PATTERNS = {
        'contract': re.compile(
            r'contract\s+(\w+)\s*(?:is\s+([\w,\s]+))?\s*\{',
            re.MULTILINE
        ),
        'function': re.compile(
            r'function\s+(\w+)\s*\(([^)]*)\)\s*(\w+)?\s*([^{;]+)',
            re.MULTILINE
        ),
        'modifier': re.compile(
            r'modifier\s+(\w+)\s*\(([^)]*)\)?\s*\{',
            re.MULTILINE
        ),
        'event': re.compile(
            r'event\s+(\w+)\s*\(([^)]*)\)',
            re.MULTILINE
        ),
        'struct': re.compile(
            r'struct\s+(\w+)\s*\{',
            re.MULTILINE
        ),
    }
    
    @staticmethod
    def analyze(filepath: str) -> List[CodeEntry]:
        entries = []
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                lines = content.split('\n')
        except Exception:
            return entries
        
        # Find contracts
        for match in SolidityAnalyzer.PATTERNS['contract'].finditer(content):
            name = match.group(1)
            line_num = content[:match.start()].count('\n') + 1
            inheritance = match.group(2) or ""
            
            entries.append(CodeEntry(
                name=name,
                file_path=filepath,
                line_number=line_num,
                entry_type="contract",
                description=f"Inherits: {inheritance}" if inheritance else "Contract",
                params=""
            ))
        
        # Find functions
        for match in SolidityAnalyzer.PATTERNS['function'].finditer(content):
            name = match.group(1)
            params = match.group(2)
            visibility = match.group(3) or ""
            modifiers = match.group(4) or ""
            line_num = content[:match.start()].count('\n') + 1
            
            entries.append(CodeEntry(
                name=name,
                file_path=filepath,
                line_number=line_num,
                entry_type="function",
                description=f"{visibility} function",
                params=f"({params})",
                visibility=visibility,
                modifiers=modifiers.strip()
            ))
        
        # Find modifiers
        for match in SolidityAnalyzer.PATTERNS['modifier'].finditer(content):
            name = match.group(1)
            params = match.group(2) or ""
            line_num = content[:match.start()].count('\n') + 1
            
            entries.append(CodeEntry(
                name=name,
                file_path=filepath,
                line_number=line_num,
                entry_type="modifier",
                description="Access control modifier",
                params=f"({params})"
            ))
        
        # Find events
        for match in SolidityAnalyzer.PATTERNS['event'].finditer(content):
            name = match.group(1)
            params = match.group(2)
            line_num = content[:match.start()].count('\n') + 1
            
            entries.append(CodeEntry(
                name=name,
                file_path=filepath,
                line_number=line_num,
                entry_type="event",
                description="Event",
                params=f"({params})"
            ))
        
        return entries


class JavaScriptAnalyzer:
    """Analyze JavaScript/TypeScript files"""
    
    PATTERNS = {
        'function': re.compile(
            r'(?:async\s+)?function\s+(\w+)\s*\(([^)]*)\)',
            re.MULTILINE
        ),
        'arrow_function': re.compile(
            r'(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s*)?\(([^)]*)\)\s*=>',
            re.MULTILINE
        ),
        'class': re.compile(
            r'class\s+(\w+)(?:\s+extends\s+(\w+))?',
            re.MULTILINE
        ),
        'method': re.compile(
            r'(?:async\s+)?(\w+)\s*\(([^)]*)\)\s*\{',
            re.MULTILINE
        ),
    }
    
    @staticmethod
    def analyze(filepath: str) -> List[CodeEntry]:
        entries = []
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
        except Exception:
            return entries
        
        # Find functions
        for match in JavaScriptAnalyzer.PATTERNS['function'].finditer(content):
            name = match.group(1)
            params = match.group(2)
            line_num = content[:match.start()].count('\n') + 1
            
            entries.append(CodeEntry(
                name=name,
                file_path=filepath,
                line_number=line_num,
                entry_type="function",
                description="Function",
                params=f"({params})"
            ))
        
        # Find classes
        for match in JavaScriptAnalyzer.PATTERNS['class'].finditer(content):
            name = match.group(1)
            extends = match.group(2)
            line_num = content[:match.start()].count('\n') + 1
            
            entries.append(CodeEntry(
                name=name,
                file_path=filepath,
                line_number=line_num,
                entry_type="class",
                description=f"Class extends {extends}" if extends else "Class",
                params=""
            ))
        
        return entries


def should_process_file(filepath: str, root_dir: str) -> bool:
    """Determine if file should be indexed"""
    # Skip hidden files
    if '/.' in filepath:
        return False
    
    # Skip ignored directories (by path component)
    rel_path = os.path.relpath(filepath, root_dir)
    for part in Path(rel_path).parts:
        if part in IGNORE_PATTERNS:
            return False
    
    # Check extension
    valid_extensions = {'.py', '.sol', '.js', '.ts', '.jsx', '.tsx'}
    return any(filepath.endswith(ext) for ext in valid_extensions)


def analyze_file(filepath: str) -> List[CodeEntry]:
    """Route file to appropriate analyzer"""
    if filepath.endswith('.py'):
        return PythonAnalyzer.analyze(filepath)
    elif filepath.endswith('.sol'):
        return SolidityAnalyzer.analyze(filepath)
    elif filepath.endswith(('.js', '.ts', '.jsx', '.tsx')):
        return JavaScriptAnalyzer.analyze(filepath)
    return []


def scan_directory(root_dir: str = '.') -> List[CodeEntry]:
    """Scan directory and analyze all files"""
    all_entries = []
    file_count = 0
    
    for root, dirs, files in os.walk(root_dir):
        # Filter out ignored directories
        dirs[:] = [d for d in dirs if d not in IGNORE_PATTERNS]
        
        for filename in files:
            filepath = os.path.join(root, filename)
            
            if should_process_file(filepath, root_dir):
                entries = analyze_file(filepath)
                if entries:
                    all_entries.extend(entries)
                    file_count += 1
    
    return all_entries, file_count


def generate_index(entries: List[CodeEntry]) -> str:
    """Generate markdown index from entries"""
    lines = [
        "# Code Index\n",
        "Auto-generated index of all functions, contracts, and classes.\n",
        "## Summary\n",
        f"Total entries: {len(entries)}\n",
        "\n## Index\n",
        "| Name | Type | File | Line | Description | Signature |",
        "|------|------|------|------|-------------|-----------|"
    ]
    
    # Sort entries by type then name
    sorted_entries = sorted(entries, key=lambda e: (e.entry_type, e.name))
    
    for entry in sorted_entries:
        # Clean up description
        desc = entry.description.replace('|', '\\|')[:50]
        
        # Clean up params
        params = entry.params.replace('|', '\\|')[:40]
        
        # Get relative path
        rel_path = entry.file_path.lstrip('./')
        
        lines.append(
            f"| `{entry.name}` | {entry.entry_type} | `{rel_path}` | "
            f"{entry.line_number} | {desc} | `{params}` |"
        )
    
    # Add statistics by type
    type_counts: Dict[str, int] = {}
    for entry in entries:
        type_counts[entry.entry_type] = type_counts.get(entry.entry_type, 0) + 1
    
    lines.extend([
        "\n## Statistics\n",
        "| Type | Count |",
        "|------|-------|"
    ])
    
    for entry_type, count in sorted(type_counts.items(), key=lambda x: -x[1]):
        lines.append(f"| {entry_type} | {count} |")
    
    return '\n'.join(lines)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Generate a semantic code index")
    parser.add_argument("--root", default=".", help="Root directory to scan")
    parser.add_argument("--output", default=DEFAULT_INDEX_FILE, help="Output markdown file")
    args = parser.parse_args()

    print("🧠 Semantic Indexing...")
    print("   Analyzing Python, Solidity, and JavaScript/TypeScript files")
    
    entries, file_count = scan_directory(args.root)
    
    if not entries:
        print("⚠️  No code entries found")
        return
    
    index_content = generate_index(entries)
    
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(index_content)
    
    print(f"✅ Updated {output_path}")
    print(f"   Files analyzed: {file_count}")
    print(f"   Total entries: {len(entries)}")
    
    # Show breakdown
    type_counts: Dict[str, int] = {}
    for entry in entries:
        type_counts[entry.entry_type] = type_counts.get(entry.entry_type, 0) + 1
    
    for entry_type, count in sorted(type_counts.items(), key=lambda x: -x[1]):
        print(f"   - {entry_type}: {count}")


if __name__ == "__main__":
    main()
