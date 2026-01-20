#!/usr/bin/env python3
import os
import ast
import re

INDEX_FILE = "CODE_INDEX.md"
IGNORE = {".git", "node_modules", "venv", "__pycache__"}

def extract_func_info(node):
    doc = ast.get_docstring(node)
    desc = doc.split("\n")[0] if doc else "No description"
    return {
        "name": node.name,
        "line": node.lineno,
        "desc": desc,
        "params": [a.arg for a in node.args.args]
    }

def get_function_defs(filepath):
    funcs = []
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            tree = ast.parse(f.read())
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                funcs.append(extract_func_info(node))
    except Exception: pass
    return funcs

def scan_files(root_dir):
    rows = []
    for root, dirs, files in os.walk(root_dir):
        dirs[:] = [d for d in dirs if d not in IGNORE]
        for name in files:
            if name.endswith(".py"): # Extend as needed
                path = os.path.join(root, name)
                for f in get_function_defs(path):
                    p = ", ".join(f["params"])
                    rp = os.path.relpath(path, root_dir)
                    rows.append(f"| `{f['name']}` | `{rp}:{f['line']}` | {f['desc']} | `({p})` |")
    return rows

def main():
    print("🧠 Semantic Indexing...")
    header = ["# Code Index\n", "| Function | Location | Description | Params |", "|---|---|---|---|"]
    rows = scan_files(".")
    
    with open(INDEX_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(header + rows))
        
    print(f"✅ Updated {INDEX_FILE} ({len(rows)} capabilities).")

if __name__ == "__main__":
    main()
