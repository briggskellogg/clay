#!/usr/bin/env python3
"""Run real transport path checks with synthetic temporary folders on macOS.

Build ClayCore first with `swift build`, or pass --core-products pointing to an
existing SwiftPM Products/Debug directory containing ClayCore.o and its module.
No connected cloud folder or application preferences are accessed.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-products", type=Path, default=ROOT / ".build/out/Products/Debug")
    parser.add_argument("--expect-alias-failure", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    products = args.core_products.resolve()
    if not (products / "ClayCore.o").is_file():
        parser.error("Build ClayCore with swift build or specify --core-products.")
    with tempfile.TemporaryDirectory(prefix="ClayFolderPathBuild-") as directory:
        temporary = Path(directory)
        source = temporary / "PathHarness.swift"
        source.write_text((ROOT / "Apps/Shared/ClaySyncFolder.swift").read_text()
                          + "\n" + (ROOT / "Tests/Integration/ClaySyncFolderPathHarness.swift").read_text())
        executable = temporary / "path-harness"
        subprocess.run(["swiftc", "-parse-as-library", "-swift-version", "5", "-I", str(products),
                        str(source), str(products / "ClayCore.o"), "-o", str(executable)], check=True)
        command = [str(executable)]
        if args.expect_alias_failure:
            command.append("--expect-alias-failure")
        subprocess.run(command, check=True)


if __name__ == "__main__":
    main()
