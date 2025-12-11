#!/usr/bin/env python3

############# Shader Deployment Script ##############
# by: hunterk
# license: public domain
#  Use this script to package shaders for distribution
#    instead of shipping the entire repo all the time.
#
#  The script expects to run from the top-level of
#    the slang shader repo. You can pass as an
#    argument the path to a preset or presets (with
#    support for wildcards) or a text file (must
#    have a *.txt file extension) with a list of
#    presets, one per line, and it will parse the
#    preset(s) and copy it/them and all of the
#    dependencies into a directory named
#    'shader_export'. Text files also support
#    recursion, such as **/*.
#
#  The default behavior is noisy but can be silenced
#    with the --silent switch, and you can print
#    the dependency tree to a text file using the
#    --LogToFile switch.
#
#####################################################

import shutil
import sys
import re
from pathlib import Path
import glob

# ------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------

REPO_ROOT = Path.cwd()
EXPORT_ROOT = REPO_ROOT / "shader_export"
DEPENDENCY_TREE_FILE = REPO_ROOT / "export_log.txt"

# Standard shader entries inside .slangp
SHADER_RE = re.compile(r'^\s*shader\d+\s*=\s*(.+)$')

# Preset chaining (#reference "path")
REFERENCE_RE = re.compile(r'^\s*#reference\s+"([^"]+)"')

# Include inside shader files
INCLUDE_RE = re.compile(r'^\s*#include\s+"([^"]+)"')

# LUTs (RetroArch: only from preset-like files)
LUT_QUOTED_RE = re.compile(r'"([^"]+\.(?:png|jpg))"', re.IGNORECASE)
LUT_BARE_RE = re.compile(r'=\s*([^\s]+\.(?:png|jpg))', re.IGNORECASE)

# Wildcards like $CORE-REQ-ROT$
WILDCARD_RE = re.compile(r'\$[A-Z0-9_\-]+\$')

# ------------------------------------------------------------
# GLOBAL STATE
# ------------------------------------------------------------

processed = set()
active_stack = []
LogToFile = False
silent = False
dependency_tree_lines = []

# ------------------------------------------------------------
# UTILITY
# ------------------------------------------------------------

def log(msg: str):
    if not silent:
        print(msg)

def clean_path(s: str) -> str:
    s = s.strip()
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'") and s.endswith("'")):
        return s[1:-1]
    return s

def normalize_relative_path(path: Path) -> Path:
    try:
        return path.resolve().relative_to(REPO_ROOT.resolve())
    except ValueError:
        return Path(path.name)

def copy_file(src: Path):
    rel = normalize_relative_path(src)
    dst = EXPORT_ROOT / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not dst.exists():
        shutil.copy2(src, dst)
        log(f"COPIED: {rel}")

def resolve_reference(base_file: Path, relative: str) -> Path:
    return (base_file.parent / relative).resolve()

def handle_wildcard_path(p: str) -> list[str]:
    if WILDCARD_RE.search(p):
        g = WILDCARD_RE.sub("*", p)
        return glob.glob(str(REPO_ROOT / g), recursive=True)
    return [p]

# ------------------------------------------------------------
# PARSERS
# ------------------------------------------------------------

def parse_shader_file(path: Path, indent: int):
    """
    Parse .slang, .inc, .h for #include statements.
    """
    with path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            m = INCLUDE_RE.match(line)
            if m:
                inc_rel = clean_path(m.group(1))
                inc_path = resolve_reference(path, inc_rel)
                log(f"{'  '*indent}INCLUDE: {inc_path.relative_to(REPO_ROOT)}")
                if LogToFile:
                    dependency_tree_lines.append(f"{'  '*indent}INCLUDE: {inc_path.relative_to(REPO_ROOT)}")
                process_file(inc_path, indent+1)

def parse_presetlike_file(path: Path, indent: int):
    """
    Parse both .slangp and .params files.
    """
    is_slangp = (path.suffix == ".slangp")
    with path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:

            # --- #reference "path/to/preset" ---
            m = REFERENCE_RE.match(line)
            if m:
                ref_rel = clean_path(m.group(1))
                ref_abs = resolve_reference(path, ref_rel)
                log(f"{'  '*indent}REFERENCE: {ref_abs.relative_to(REPO_ROOT)}")
                if LogToFile:
                    dependency_tree_lines.append(f"{'  '*indent}REFERENCE: {ref_abs.relative_to(REPO_ROOT)}")
                process_file(ref_abs, indent+1)
                continue

            # --- shaderN = X (only in .slangp) ---
            if is_slangp:
                m = SHADER_RE.match(line)
                if m:
                    raw = clean_path(m.group(1).strip())
                    for expanded in handle_wildcard_path(raw):
                        ref_abs = resolve_reference(path, expanded)
                        log(f"{'  '*indent}SHADER: {ref_abs.relative_to(REPO_ROOT)}")
                        if LogToFile:
                            dependency_tree_lines.append(f"{'  '*indent}SHADER: {ref_abs.relative_to(REPO_ROOT)}")
                        process_file(ref_abs, indent+1)
                    continue

            # --- LUTs (png/jpg only) ---
            for img in LUT_QUOTED_RE.findall(line):
                lut_path = resolve_reference(path, clean_path(img))
                if lut_path.exists():
                    copy_file(lut_path)
            m = LUT_BARE_RE.search(line)
            if m:
                lut_path = resolve_reference(path, clean_path(m.group(1)))
                if lut_path.exists():
                    copy_file(lut_path)

# ------------------------------------------------------------
# CORE DISPATCH
# ------------------------------------------------------------

def process_file(path: Path, indent: int = 0):
    path = path.resolve()

    if path.is_dir():
        return  # skip directories

    if not path.exists():
        log(f"WARNING: Missing file: {path}")
        return

    if path in active_stack:
        log(f"WARNING: Circular reference/include detected: {path}")
        return

    if path in processed:
        return

    active_stack.append(path)
    copy_file(path)

    # Log starting message for presets
    if indent == 0:
        log(f"PROCESSING PRESET: {path.relative_to(REPO_ROOT)}")
        if LogToFile:
            dependency_tree_lines.append(f"PRESET: {path.relative_to(REPO_ROOT)}")

    # Dispatch parser
    if path.suffix in {".slangp", ".params"}:
        parse_presetlike_file(path, indent)
    elif path.suffix in {".slang", ".inc", ".h"}:
        parse_shader_file(path, indent)
    else:
        pass  # images or data

    processed.add(path)
    active_stack.pop()

# ------------------------------------------------------------
# INPUT EXPANSION
# ------------------------------------------------------------

def load_targets_from_file(txt_path: Path) -> list[str]:
    items = []
    with txt_path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            items.append(line)
    return items

def expand_input_arg(arg: str) -> list[Path]:
    p = Path(arg)
    if p.exists() and p.is_file() and p.suffix.lower() == ".txt":
        paths = load_targets_from_file(p)
        return expand_preset_inputs(paths)
    matches = glob.glob(arg, recursive=True)
    if matches:
        return [Path(m).resolve() for m in matches]
    else:
        return [Path(arg).resolve()]

def expand_preset_inputs(args: list[str]) -> list[Path]:
    out = []
    for a in args:
        out.extend(expand_input_arg(a))
    return out

# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------

def main():
    global LogToFile, silent
    if len(sys.argv) < 2:
        print("Usage: shader_deploy.py [--LogToFile] [--silent] <preset_or_list> [...]")
        sys.exit(1)

    # Parse flags
    args = []
    for a in sys.argv[1:]:
        if a == "--LogToFile":
            LogToFile = True
        elif a == "--silent":
            silent = True
        else:
            args.append(a)

    EXPORT_ROOT.mkdir(exist_ok=True)
    presets = expand_preset_inputs(args)

    for preset in presets:
        process_file(preset)

    # Write dependency tree if requested
    if LogToFile:
        DEPENDENCY_TREE_FILE.parent.mkdir(parents=True, exist_ok=True)
        with DEPENDENCY_TREE_FILE.open("w", encoding="utf-8") as f:
            f.write("\n".join(dependency_tree_lines))
        log(f"Dependency tree written to {DEPENDENCY_TREE_FILE}")

if __name__ == "__main__":
    main()
