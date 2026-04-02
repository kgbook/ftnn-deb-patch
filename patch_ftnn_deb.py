#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def patch_preinst(preinst: Path) -> None:
    if not preinst.is_file():
        raise FileNotFoundError(f"preinst not found: {preinst}")

    text = preinst.read_text(encoding="utf-8")
    if "Non-Ubuntu system detected" in text:
        return

    replacements = [
        (
            ". /etc/lsb-release\n        os_version=$DISTRIB_RELEASE",
            ". /etc/lsb-release\n"
            "        os_id=$(echo \"${DISTRIB_ID:-unknown}\" | tr '[:upper:]' '[:lower:]')\n"
            "        os_version=$DISTRIB_RELEASE",
        ),
        (
            ". /etc/os-release\n        os_version=$VERSION_ID",
            ". /etc/os-release\n"
            "        os_id=$(echo \"${ID:-unknown}\" | tr '[:upper:]' '[:lower:]')\n"
            "        os_version=$VERSION_ID",
        ),
        (
            "    else\n"
            "        Log \"ERROR\" \"Unable to determine OS version.\"\n"
            "        exit 1\n"
            "    fi\n",
            "    else\n"
            "        Log \"ERROR\" \"Unable to determine OS version.\"\n"
            "        exit 1\n"
            "    fi\n\n"
            "    os_id=${os_id:-unknown}\n"
            "    os_version=${os_version:-0}\n",
        ),
        (
            "if [ $os_version_num -lt 1804 ]; then",
            'if [ "$os_id" = "ubuntu" ] && [ $os_version_num -lt 1804 ]; then',
        ),
        (
            '    Log "INFO" "OS version check passed. Current version: $os_version"',
            '    if [ "$os_id" = "ubuntu" ]; then\n'
            '        Log "INFO" "OS version check passed. Current Ubuntu version: $os_version"\n'
            "    else\n"
            '        Log "INFO" "Non-Ubuntu system detected ($os_id $os_version). Skipping Ubuntu 18.04 minimum version check."\n'
            "    fi",
        ),
    ]

    patched = text
    for old, new in replacements:
        if old not in patched:
            raise RuntimeError(f"expected preinst snippet not found: {old!r}")
        patched = patched.replace(old, new, 1)

    if "Non-Ubuntu system detected" not in patched:
        raise RuntimeError("patch verification failed")

    preinst.write_text(patched, encoding="utf-8")


def derive_output_path(input_deb: Path, output_deb: str | None) -> Path:
    if output_deb:
        return Path(output_deb).expanduser().resolve()
    return input_deb.with_name(f"{input_deb.stem}_patched.deb")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Patch FTNN desktop .deb packages in the current directory or any specified path to skip the Ubuntu-only version restriction on non-Ubuntu systems."
    )
    parser.add_argument("input_deb", help="Path to the original .deb package")
    parser.add_argument("output_deb", nargs="?", help="Optional output path")
    args = parser.parse_args()

    input_deb = Path(args.input_deb).expanduser().resolve()
    output_deb = derive_output_path(input_deb, args.output_deb)

    if not input_deb.is_file():
        print(f"input .deb not found: {input_deb}", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory(prefix="ftnn-deb-patch.") as temp_dir_str:
        temp_dir = Path(temp_dir_str)
        control_dir = temp_dir / "control"
        data_dir = temp_dir / "data"
        repack_dir = temp_dir / "repack"

        control_dir.mkdir()
        data_dir.mkdir()
        (repack_dir / "DEBIAN").mkdir(parents=True)

        print(f"Extracting control files from: {input_deb}")
        run(["dpkg-deb", "-e", str(input_deb), str(control_dir)])

        print("Patching Ubuntu distro check in preinst")
        patch_preinst(control_dir / "preinst")

        print("Extracting package payload")
        run(["dpkg-deb", "-x", str(input_deb), str(data_dir)])

        shutil.copytree(control_dir, repack_dir / "DEBIAN", dirs_exist_ok=True)
        shutil.copytree(data_dir, repack_dir, dirs_exist_ok=True)

        if output_deb.exists():
            output_deb.unlink()

        print(f"Building patched package: {output_deb}")
        run(
            [
                "dpkg-deb",
                "--root-owner-group",
                "-b",
                str(repack_dir),
                str(output_deb),
            ]
        )

    print("Done")
    print(output_deb)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
