#!/usr/bin/env python3
"""Check source packaging and project wiring without claiming a native build.

Runs with Python's standard library on Linux or macOS. Native compilation and
Swift tests must be run separately on a Mac using scripts/build.sh.
"""
from __future__ import annotations

import json
import plistlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class OpenStepParser:
    def __init__(self, text: str):
        self.tokens = []
        pattern = re.compile(r'\s+|//[^\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,"/]+', re.S)
        position = 0
        for match in pattern.finditer(text):
            if match.start() != position:
                raise ValueError(f"Unrecognized project text at {position}")
            position = match.end()
            token = match.group()
            if token.isspace() or token.startswith("//") or token.startswith("/*"):
                continue
            self.tokens.append(token)
        if position != len(text):
            raise ValueError("Unparsed project suffix")
        self.index = 0

    def take(self, expected=None):
        value = self.tokens[self.index]
        self.index += 1
        if expected is not None:
            assert value == expected, (expected, value)
        return value

    def parse(self):
        token = self.take()
        if token == "{":
            result = {}
            while self.tokens[self.index] != "}":
                key = self.parse()
                self.take("=")
                assert key not in result, f"Duplicate key {key}"
                result[key] = self.parse()
                self.take(";")
            self.take("}")
            return result
        if token == "(":
            result = []
            while self.tokens[self.index] != ")":
                result.append(self.parse())
                if self.tokens[self.index] != ")": self.take(",")
            self.take(")")
            return result
        if token.startswith('"'):
            return json.loads(token)
        return int(token) if token.isdigit() else token


def main():
    parser = OpenStepParser((ROOT / "Clay.xcodeproj/project.pbxproj").read_text())
    project = parser.parse()
    assert parser.index == len(parser.tokens)
    objects = project["objects"]
    root = objects[project["rootObject"]]
    assert root["isa"] == "PBXProject"
    targets = [objects[ref] for ref in root["targets"]]
    assert {target["name"] for target in targets} == {"Clay-macOS", "Clay-iOS"}

    swift_files = {p.relative_to(ROOT).as_posix() for p in ROOT.glob("Apps/**/*.swift")}
    for target in targets:
        platform = "macOS" if target["name"] == "Clay-macOS" else "iOS"
        phases = [objects[ref] for ref in target["buildPhases"]]
        sources_phase = next(p for p in phases if p["isa"] == "PBXSourcesBuildPhase")
        paths = {objects[objects[ref]["fileRef"]]["path"] for ref in sources_phase["files"]}
        expected = {p for p in swift_files if p.startswith(("Apps/Shared/", f"Apps/{platform}/"))}
        assert paths == expected, (target["name"], "source membership mismatch", paths ^ expected)
        assert sum((ROOT / path).read_text().count("@main") for path in paths) == 1
        resources_phase = next(p for p in phases if p["isa"] == "PBXResourcesBuildPhase")
        resources = {objects[objects[ref]["fileRef"]]["path"] for ref in resources_phase["files"]}
        assert {"Resources/Fonts", "Resources/Assets.xcassets", "Resources/PrivacyInfo.xcprivacy"} <= resources
        dependency = objects[target["packageProductDependencies"][0]]
        assert dependency["productName"] == "ClayCore"
        assert objects[dependency["package"]]["relativePath"] == "."
        configs = objects[target["buildConfigurationList"]]["buildConfigurations"]
        for ref in configs:
            configuration = objects[ref]
            settings = configuration["buildSettings"]
            assert (ROOT / settings["INFOPLIST_FILE"]).is_file()
            assert settings["PRODUCT_NAME"] == "Clay"
            assert settings["ASSETCATALOG_COMPILER_APPICON_NAME"] == "AppIcon"
            assert objects[configuration["baseConfigurationReference"]]["path"] == "Config/Shared.xcconfig"

    for obj in objects.values():
        if obj["isa"] == "PBXFileReference" and obj.get("sourceTree") == "SOURCE_ROOT":
            assert (ROOT / obj["path"]).exists(), obj["path"]
        for key in ["buildConfigurationList", "fileRef", "productRef", "productReference", "baseConfigurationReference", "mainGroup", "productRefGroup", "package"]:
            if key in obj: assert obj[key] in objects, (key, obj[key])
        for key in ["buildPhases", "files", "children", "buildConfigurations", "targets", "packageReferences", "packageProductDependencies"]:
            for ref in obj.get(key, []): assert ref in objects, (key, ref)

    for path in [*ROOT.glob("Config/*.plist"), *ROOT.glob("Config/*.entitlements"), ROOT / "Resources/PrivacyInfo.xcprivacy"]:
        assert isinstance(plistlib.loads(path.read_bytes()), dict)
    ios_info = plistlib.loads((ROOT / "Config/Info-iOS.plist").read_bytes())
    for font in ios_info["UIAppFonts"]:
        assert (ROOT / "Resources" / font).is_file(), font
    privacy = plistlib.loads((ROOT / "Resources/PrivacyInfo.xcprivacy").read_bytes())
    assert privacy["NSPrivacyTracking"] is False
    assert privacy["NSPrivacyCollectedDataTypes"] == []

    for path in ROOT.glob("Clay.xcodeproj/xcshareddata/xcschemes/*.xcscheme"):
        scheme = ET.parse(path)
        for ref in scheme.findall(".//BuildableReference"):
            assert ref.attrib["BlueprintIdentifier"] in objects
            assert ref.attrib["BlueprintName"] in {target["name"] for target in targets}
    ET.parse(ROOT / "Clay.xcodeproj/project.xcworkspace/contents.xcworkspacedata")
    for path in ROOT.glob("Resources/Assets.xcassets/**/Contents.json"):
        json.loads(path.read_text())
    for path in [*ROOT.glob("scripts/*.sh"), ROOT / "Install Clay.command"]:
        subprocess.run(["bash", "-n", str(path)], check=True)
        assert path.stat().st_mode & 0o111, f"Missing executable bit: {path.name}"
    for path in ROOT.glob("scripts/*.py"):
        compile(path.read_text(), str(path), "exec")
    tests = sum(len(re.findall(r"\bfunc test\w+", p.read_text())) for p in ROOT.glob("Tests/ClayCoreTests/*.swift"))
    print(f"PASS: project syntax/graph, both targets, {len(swift_files)} Swift app source memberships, resources, fonts, plists, schemes, asset manifests, shell and Python syntax.")
    print(f"PRESENT, NOT RUN: {tests} Swift XCTest methods. No native compilation, signing, device launch or upload was performed by this check.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Source validation failed: {error}", file=sys.stderr)
        raise
