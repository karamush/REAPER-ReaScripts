from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path
from textwrap import dedent

# =========================================================
# Paths
# =========================================================

BASE_DIR = Path(__file__).resolve().parents[1]
LIB_DIR = BASE_DIR / "_lib"
VERSION_FILE = BASE_DIR / "VERSION"

GROUPS = 12

PACKAGE_NAME = "LiveRecGroups"
AUTHOR = "Karamush"
ABOUT = f"{PACKAGE_NAME} provides track grouping features for live recording/streaming in REAPER."

MAIN_PACKAGE_FILE = BASE_DIR / f"{PACKAGE_NAME}.lua"
LIB_FILE = LIB_DIR / f"{PACKAGE_NAME}.lua"

# =========================================================
# Versioning
# =========================================================


def get_version() -> str:
    if VERSION_FILE.exists():
        return VERSION_FILE.read_text().strip()

    github_ref = os.getenv("GITHUB_REF_NAME")

    if github_ref:
        return github_ref.removeprefix("v")

    try:
        tag = subprocess.check_output(
            [
                "git",
                "describe",
                "--tags",
                "--exact-match",
            ],
            text=True,
        ).strip()

        return tag.removeprefix("v")

    except Exception:
        pass

    try:
        sha = subprocess.check_output(
            [
                "git",
                "rev-parse",
                "--short",
                "HEAD",
            ],
            text=True,
        ).strip()

        return f"0.0.0-dev+{sha}"

    except Exception:
        return "0.0.0-dev"


VERSION = get_version()

# =========================================================
# Helpers
# =========================================================


def lua_header(
    description: str,
    *,
    noindex: bool = False,
    metapackage: bool = False,
    provides: list[str] | None = None,
) -> str:
    lines = []

    if noindex:
        lines.append("-- @noindex")
    else:
        lines.extend(
            [
                f"-- @description {description}",
                f"-- @version {VERSION}",
                f"-- @author {AUTHOR}",
                "-- @about",
                f"--    {ABOUT}",
            ]
        )

    if metapackage:
        lines.append("-- @metapackage")

    if provides:
        lines.append("-- @provides")

        for item in provides:
            lines.append(f"--    {item}")

    return "\n".join(lines)


def prelude() -> str:
    return dedent(
        r"""
local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("^(.*[\\/])")

local LR = dofile(script_dir .. "_lib/LiveRecGroups.lua")

local _, _, section_id, cmd_id, _, _, _ = reaper.get_action_context()
"""
    ).strip()


def write_file(path: Path, content: str) -> None:
    path.write_text(content.rstrip() + "\n", encoding="utf-8")


# =========================================================
# Wrapper generation
# =========================================================


def toggle_wrapper(group_id: int) -> tuple[str, str]:
    filename = f"Toggle Track Group {group_id:02d} ({PACKAGE_NAME}).lua"

    content = dedent(
        f"""{lua_header(f"Toggle Track Group {group_id:02d}", noindex=True)}
{prelude()}

local GROUP_ID = {group_id}

local state = LR.toggle_group(GROUP_ID)

if state ~= nil then
    LR.refresh_toolbar(section_id, cmd_id, state)
end
        """
    ).strip()

    return filename, content


def save_wrapper(group_id: int) -> tuple[str, str]:
    filename = (
        f"Save Selected Tracks To Group {group_id:02d} "
        f"({PACKAGE_NAME}).lua"
    )

    content = dedent(
        f"""
{lua_header(f"Save Selected Tracks To Group {group_id:02d}", noindex=True)}

{prelude()}

local GROUP_ID = {group_id}

reaper.Undo_BeginBlock()

local count = LR.save_selected_tracks_to_group(GROUP_ID)

reaper.Undo_EndBlock(
    "Save selected tracks to LiveRecGroups",
    -1
)

reaper.ShowConsoleMsg(
    ("Saved %d track(s) to group %d\\n")
    :format(count, GROUP_ID)
)
        """
    ).strip()

    return filename, content


def select_wrapper(group_id: int) -> tuple[str, str]:
    filename = (
        f"Select Tracks In Group {group_id:02d} "
        f"({PACKAGE_NAME}).lua"
    )

    content = dedent(
        f"""
{lua_header(f"Select Tracks In Group {group_id:02d}", noindex=True)}

{prelude()}

local GROUP_ID = {group_id}

LR.select_group(GROUP_ID)
        """
    ).strip()

    return filename, content


# =========================================================
# Main metapackage
# =========================================================


def generate_main_package(wrapper_files: list[str]) -> str:
    provides = []

    for file in wrapper_files:
        provides.append(f"[main] {file}")

    provides.append("[nomain] _lib/LiveRecGroups.lua")

    return dedent(
        f"""
        {lua_header(
            PACKAGE_NAME,
            metapackage=True,
            provides=provides,
        )}

-- This file is auto-generated.
        """
    ).strip()


# =========================================================
# Library version patching
# =========================================================


def patch_library_version() -> None:
    if not LIB_FILE.exists():
        print(f"WARNING: library file not found: {LIB_FILE}")
        return

    content = LIB_FILE.read_text(encoding="utf-8")

    if "@version" in content:
        content = re.sub(
            r"(-- @version\\s+)(.+)",
            rf"\\g<1>{VERSION}",
            content,
        )
    else:
        header = dedent(
            f"""
            -- @noindex
            -- @version {VERSION}

            """
        )

        content = header + content

    write_file(LIB_FILE, content)


def clear_old_scripts() -> None:
    for script_file in BASE_DIR.glob("*.lua"):
        try:
            script_file.unlink()
        except OSError as exc:
            print(f"WARNING: failed to delete {script_file}: {exc}")


# =========================================================
# Main
# =========================================================


def main() -> None:
    BASE_DIR.mkdir(parents=True, exist_ok=True)
    LIB_DIR.mkdir(parents=True, exist_ok=True)

    clear_old_scripts()

    wrapper_files: list[str] = []

    generators = [
        toggle_wrapper,
        save_wrapper,
        select_wrapper,
    ]

    for group_id in range(1, GROUPS + 1):
        for generator in generators:
            filename, content = generator(group_id)

            wrapper_files.append(filename)

            write_file(BASE_DIR / filename, content)

    main_package = generate_main_package(wrapper_files)

    write_file(MAIN_PACKAGE_FILE, main_package)

    patch_library_version()

    print(f"Generated package: {PACKAGE_NAME}")
    print(f"Generated wrappers: {len(wrapper_files)}")
    print(f"Version: {VERSION}")


if __name__ == "__main__":
    main()