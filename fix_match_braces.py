#!/usr/bin/env python3
"""
Fix Cangjie match case syntax: remove curly braces from case bodies.
In Cangjie, match case bodies should NOT use curly braces:
  case X => { stmt1; stmt2 }  ->  case X => stmt1; stmt2
"""

import os
import re
import sys

def fix_match_braces(content):
    lines = content.split('\n')
    result = []
    i = 0
    changed = False

    while i < len(lines):
        line = lines[i]
        stripped = line.rstrip()

        # Check if this line has a match case with opening brace
        # Pattern: case ... => {
        # But NOT inside a comment or string
        match = re.match(r'^(\s*case\s+.*=>)\s*\{\s*$', stripped)
        if match:
            indent = len(line) - len(line.lstrip())
            indent_str = line[:indent]

            # Remove the opening brace
            new_line = match.group(1)
            result.append(new_line)

            # Now find the matching closing brace
            brace_depth = 1
            body_lines = []
            j = i + 1
            while j < len(lines) and brace_depth > 0:
                inner_line = lines[j]
                inner_stripped = inner_line.strip()

                # Count braces (but not in strings/comments - simplified)
                for ch in inner_stripped:
                    if ch == '{':
                        brace_depth += 1
                    elif ch == '}':
                        brace_depth -= 1

                if brace_depth == 0:
                    # This line has the closing brace
                    # Check if the line is just "}" or has more content
                    if inner_stripped == '}':
                        # Just a closing brace - skip it
                        pass
                    else:
                        # Has content before or after the brace - strip the trailing }
                        # Find last } and remove it
                        last_brace = inner_line.rfind('}')
                        cleaned = inner_line[:last_brace].rstrip()
                        if cleaned.strip():
                            body_lines.append(cleaned)
                    break
                else:
                    body_lines.append(inner_line)
                j += 1

            if brace_depth == 0:
                # Check if body is empty (only comments/whitespace)
                has_code = any(l.strip() and not l.strip().startswith('//') for l in body_lines)
                if not has_code:
                    # Empty body - add () as a no-op expression
                    result.append(indent_str + '    ()')
                else:
                    result.extend(body_lines)
                i = j + 1
                changed = True
                continue
            else:
                # Unmatched brace - keep original
                result.append(line)
        else:
            result.append(line)
        i += 1

    return '\n'.join(result), changed

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    new_content, changed = fix_match_braces(content)
    if changed:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Fixed: {filepath}")
    return changed

def main():
    src_dir = sys.argv[1] if len(sys.argv) > 1 else '/data2/wangjun/github/bao/packages/bao_bundler/src'

    total_fixed = 0
    for root, dirs, files in os.walk(src_dir):
        for fname in files:
            if fname.endswith('.cj'):
                filepath = os.path.join(root, fname)
                if process_file(filepath):
                    total_fixed += 1

    print(f"Total files fixed: {total_fixed}")

if __name__ == '__main__':
    main()
