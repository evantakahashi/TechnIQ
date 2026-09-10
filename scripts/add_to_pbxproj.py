#!/usr/bin/env python3
"""Add Swift files to TechnIQ.xcodeproj (explicit file references, no synchronized groups).

Usage:
  add_to_pbxproj.py <group-path> <file1.swift> [file2.swift ...]

<group-path> is relative to TechnIQ/ (e.g. "Components/Touchline"). Intermediate groups are
created on demand (path = last component, nested under the parent group). The build file is
added to the TechnIQ app target's Sources phase (DF1635F42E133001001E8CF9).
Files already present are skipped. IDs are deterministic 24-hex hashes of the path.
"""
import hashlib
import re
import sys

PBX = "/Users/evantakahashi/TechnIQ/.claude/worktrees/touchline/TechnIQ.xcodeproj/project.pbxproj"
APP_SOURCES_PHASE = "DF1635F42E133001001E8CF9"
TESTS_SOURCES_PHASE = "DF1636042E133003001E8CF9"
TESTS_GROUP = "DF16360B2E133003001E8CF9"
UITESTS_SOURCES_PHASE = "DF16360E2E133003001E8CF9"
UITESTS_GROUP = "DF1636152E133003001E8CF9"
ROOT_GROUP_TECHNIQ = None  # resolved dynamically: the group with `path = TechnIQ;`


def hid(s: str) -> str:
    return hashlib.sha1(s.encode()).hexdigest()[:24].upper()


def find_group_id(text: str, name: str, parent_id: str | None) -> str | None:
    """Return the id of a PBXGroup whose `path = <name>;` and which is a child of parent_id."""
    for m in re.finditer(r"\n\t\t([0-9A-Z]{24,26}) /\* ([^*]+) \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \((.*?)\);\n(.*?)\n\t\t\};", text, re.S):
        gid, _gname, _children, tail = m.groups()
        if re.search(r"(^|\n)\t\t\tpath = %s;" % re.escape(name), tail):
            if parent_id is None:
                return gid
            # check membership in parent
            pm = re.search(r"\n\t\t%s /\* [^*]+ \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \((.*?)\);" % parent_id, text, re.S)
            if pm and gid in pm.group(1):
                return gid
    return None


def add_child_to_group(text: str, group_id: str, child_line: str) -> str:
    pat = re.compile(r"(\n\t\t%s /\* [^*]+ \*/ = \{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \()(.*?)(\);)" % group_id, re.S)
    m = pat.search(text)
    assert m, f"group {group_id} not found"
    children = m.group(2)
    if child_line.strip() in children:
        return text
    new_children = children.rstrip() + "\n" + child_line + "\n\t\t\t"
    return text[: m.start(2)] + new_children + text[m.end(2):]


def ensure_group(text: str, path_components: list[str]) -> tuple[str, str]:
    """Ensure nested groups exist; return (text, leaf group id)."""
    # root: the TechnIQ group (path = TechnIQ)
    parent = find_group_id(text, "TechnIQ", None)
    assert parent, "TechnIQ root group not found"
    full = "TechnIQ"
    for comp in path_components:
        full += "/" + comp
        gid = find_group_id(text, comp, parent)
        if gid is None:
            gid = hid("group:" + full)
            block = (
                f"\n\t\t{gid} /* {comp} */ = {{\n"
                f"\t\t\tisa = PBXGroup;\n"
                f"\t\t\tchildren = (\n"
                f"\t\t\t);\n"
                f"\t\t\tpath = {comp};\n"
                f"\t\t\tsourceTree = \"<group>\";\n"
                f"\t\t}};"
            )
            idx = text.index("/* End PBXGroup section */")
            text = text[:idx].rstrip("\n") + block + "\n" + text[idx:]
            text = add_child_to_group(text, parent, f"\t\t\t\t{gid} /* {comp} */,")
            print(f"created group {comp} ({gid})")
        parent = gid
    return text, parent


def add_file(text: str, group_id: str, group_path: str, filename: str, phase: str = APP_SOURCES_PHASE) -> str:
    rel = f"{group_path}/{filename}"
    if re.search(r"/\* %s \*/ = \{isa = PBXFileReference" % re.escape(filename), text):
        print(f"skip (exists): {filename}")
        return text
    fid = hid("file:" + rel)
    bid = hid("build:" + rel)
    # PBXBuildFile
    bf = f"\t\t{bid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {filename} */; }};\n"
    idx = text.index("/* Begin PBXBuildFile section */") + len("/* Begin PBXBuildFile section */\n")
    text = text[:idx] + bf + text[idx:]
    # PBXFileReference
    fr = f"\t\t{fid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n"
    idx = text.index("/* Begin PBXFileReference section */") + len("/* Begin PBXFileReference section */\n")
    text = text[:idx] + fr + text[idx:]
    # group child
    text = add_child_to_group(text, group_id, f"\t\t\t\t{fid} /* {filename} */,")
    # sources phase
    pat = re.compile(r"(\n\t\t%s /\* Sources \*/ = \{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = \d+;\n\t\t\tfiles = \()(.*?)(\);)" % phase, re.S)
    m = pat.search(text)
    assert m, "app sources phase not found"
    files = m.group(2).rstrip() + f"\n\t\t\t\t{bid} /* {filename} in Sources */,\n\t\t\t"
    text = text[: m.start(2)] + files + text[m.end(2):]
    print(f"added {rel}")
    return text


def remove_file(text: str, filename: str) -> str:
    """Remove every pbxproj line that references <filename> (build file, file ref, group child, sources)."""
    pattern = re.compile(r"^.*/\* %s( in Sources)? \*/.*\n" % re.escape(filename), re.M)
    text, n = pattern.subn("", text)
    print(f"removed {filename}: {n} lines")
    return text


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    args = sys.argv[1:]
    if args[0] == "--remove":
        text = open(PBX).read()
        for f in args[1:]:
            text = remove_file(text, f)
        open(PBX, "w").write(text)
        return
    tests = False
    uitests = False
    if args[0] == "--tests":
        tests = True
        args = args[1:]
    elif args[0] == "--uitests":
        uitests = True
        args = args[1:]
    group_path = args[0].strip("/")
    files = args[1:]
    text = open(PBX).read()
    if tests:
        # group_path must be "TechnIQTests"; files land in the tests root group / tests target
        gid, phase = TESTS_GROUP, TESTS_SOURCES_PHASE
    elif uitests:
        gid, phase = UITESTS_GROUP, UITESTS_SOURCES_PHASE
    else:
        text, gid = ensure_group(text, group_path.split("/"))
        phase = APP_SOURCES_PHASE
    for f in files:
        text = add_file(text, gid, group_path, f, phase)
    open(PBX, "w").write(text)


if __name__ == "__main__":
    main()
