#!/usr/bin/env python3
"""Regenerate the dependency-free Xcode project from its Swift source folders.

Python is needed only for regeneration, not for building the checked-in project.
This generator owns project.pbxproj, shared schemes and platform Info plists.
Signing.local.xcconfig is never read or modified.
"""
from __future__ import annotations

import hashlib
import json
import plistlib
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OBJECTS: dict[str, dict] = {}


def identifier(key: str) -> str:
    return hashlib.sha1(key.encode()).hexdigest()[:24].upper()


def add(key: str, isa: str, **values) -> str:
    ident = identifier(key)
    assert ident not in OBJECTS, key
    OBJECTS[ident] = {"isa": isa, **values}
    return ident


def serialize(value, level: int = 0) -> str:
    if isinstance(value, dict):
        contents = ["\t" * (level + 1) + json.dumps(key) + " = " + serialize(item, level + 1) + ";"
                    for key, item in value.items()]
        return "{\n" + "\n".join(contents) + "\n" + "\t" * level + "}"
    if isinstance(value, list):
        return "(\n" + "\n".join("\t" * (level + 1) + serialize(item, level + 1) + "," for item in value) + "\n" + "\t" * level + ")"
    if isinstance(value, int):
        return str(value)
    return json.dumps(str(value), ensure_ascii=False)


def write_plist(path: str, values: dict) -> None:
    output = ROOT / path
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(plistlib.dumps(values, sort_keys=False))


def make_config() -> None:
    common = {
        "CFBundleDevelopmentRegion": "en",
        "CFBundleDisplayName": "Clay",
        "CFBundleExecutable": "$(EXECUTABLE_NAME)",
        "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "$(MARKETING_VERSION)",
        "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
        "ITSAppUsesNonExemptEncryption": False,
    }
    markdown = {
        "UTTypeIdentifier": "net.daringfireball.markdown",
        "UTTypeDescription": "Markdown document",
        "UTTypeConformsTo": ["public.plain-text"],
        "UTTypeTagSpecification": {
            "public.filename-extension": ["md", "markdown"],
            "public.mime-type": ["text/markdown"],
        },
    }
    documents = [{
        "CFBundleTypeName": "Markdown and text",
        "CFBundleTypeRole": "Editor",
        "LSHandlerRank": "Alternate",
        "LSItemContentTypes": ["net.daringfireball.markdown", "public.plain-text"],
    }]
    write_plist("Config/Info-macOS.plist", {
        **common,
        "LSMinimumSystemVersion": "$(MACOSX_DEPLOYMENT_TARGET)",
        "LSApplicationCategoryType": "public.app-category.productivity",
        "NSHighResolutionCapable": True,
        "NSHumanReadableCopyright": "Copyright © 2026 Clay",
        "NSPrincipalClass": "NSApplication",
        "ATSApplicationFontsPath": "Fonts",
        "CFBundleDocumentTypes": documents,
        "UTImportedTypeDeclarations": [markdown],
    })
    write_plist("Config/Info-iOS.plist", {
        **common,
        "LSRequiresIPhoneOS": True,
        "LSSupportsOpeningDocumentsInPlace": True,
        "UILaunchScreen": {},
        "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False},
        "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"],
        "UISupportedInterfaceOrientations~ipad": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationPortraitUpsideDown", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"],
        "UIAppFonts": ["Fonts/PPNeueMontreal-Regular.ttf", "Fonts/PPNeueMontreal-Bold.ttf", "Fonts/PPNeueYork-NormalLight.otf"],
        "CFBundleDocumentTypes": documents,
        "UTImportedTypeDeclarations": [markdown],
    })
    write_plist("Config/Clay-macOS.entitlements", {
        "com.apple.security.app-sandbox": True,
        "com.apple.security.files.user-selected.read-write": True,
        "com.apple.security.files.bookmarks.app-scope": True,
    })
    write_plist("Resources/PrivacyInfo.xcprivacy", {
        "NSPrivacyTracking": False,
        "NSPrivacyTrackingDomains": [],
        "NSPrivacyCollectedDataTypes": [],
        "NSPrivacyAccessedAPITypes": [{
            "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
            "NSPrivacyAccessedAPITypeReasons": ["CA92.1"],
        }],
    })


def make_scheme(name: str, target_id: str) -> None:
    root = ET.Element("Scheme", LastUpgradeVersion="2600", version="1.3")
    build = ET.SubElement(root, "BuildAction", parallelizeBuildables="YES", buildImplicitDependencies="YES")
    entries = ET.SubElement(build, "BuildActionEntries")
    entry = ET.SubElement(entries, "BuildActionEntry", buildForTesting="YES", buildForRunning="YES", buildForProfiling="YES", buildForArchiving="YES", buildForAnalyzing="YES")
    ref = dict(BuildableIdentifier="primary", BlueprintIdentifier=target_id, BuildableName="Clay.app", BlueprintName=name, ReferencedContainer="container:Clay.xcodeproj")
    ET.SubElement(entry, "BuildableReference", **ref)
    ET.SubElement(root, "TestAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB", selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", shouldUseLaunchSchemeArgsEnv="YES")
    launch = ET.SubElement(root, "LaunchAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB", selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", launchStyle="0", useCustomWorkingDirectory="NO", ignoresPersistentStateOnLaunch="NO", debugDocumentVersioning="YES", debugServiceExtension="internal", allowLocationSimulation="YES")
    runnable = ET.SubElement(launch, "BuildableProductRunnable", runnableDebuggingMode="0")
    ET.SubElement(runnable, "BuildableReference", **ref)
    profile = ET.SubElement(root, "ProfileAction", buildConfiguration="Release", shouldUseLaunchSchemeArgsEnv="YES", savedToolIdentifier="", useCustomWorkingDirectory="NO", debugDocumentVersioning="YES")
    runnable = ET.SubElement(profile, "BuildableProductRunnable", runnableDebuggingMode="0")
    ET.SubElement(runnable, "BuildableReference", **ref)
    ET.SubElement(root, "AnalyzeAction", buildConfiguration="Debug")
    ET.SubElement(root, "ArchiveAction", buildConfiguration="Release", revealArchiveInOrganizer="YES")
    ET.indent(root)
    folder = ROOT / "Clay.xcodeproj/xcshareddata/xcschemes"
    folder.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(root).write(folder / f"{name}.xcscheme", encoding="UTF-8", xml_declaration=True)


def make_project() -> None:
    files: dict[str, str] = {}
    all_sources = sorted(ROOT.glob("Apps/**/*.swift"))
    for source in all_sources:
        relative = source.relative_to(ROOT).as_posix()
        files[relative] = add("file:" + relative, "PBXFileReference", lastKnownFileType="sourcecode.swift", path=relative, sourceTree="SOURCE_ROOT")
    for path, filetype in [
        ("Resources/Fonts", "folder"),
        ("Resources/Assets.xcassets", "folder.assetcatalog"),
        ("Resources/PrivacyInfo.xcprivacy", "text.xml"),
        ("Config/Shared.xcconfig", "text.xcconfig"),
        ("Config/Info-macOS.plist", "text.plist.xml"),
        ("Config/Info-iOS.plist", "text.plist.xml"),
        ("Config/Clay-macOS.entitlements", "text.plist.entitlements"),
        ("Package.swift", "sourcecode.swift"),
    ]:
        files[path] = add("file:" + path, "PBXFileReference", lastKnownFileType=filetype, path=path, sourceTree="SOURCE_ROOT")

    package = add("local-package", "XCLocalSwiftPackageReference", relativePath=".")
    products: list[str] = []
    targets: list[str] = []
    for platform, name in [("macOS", "Clay-macOS"), ("iOS", "Clay-iOS")]:
        product = add("product:" + name, "PBXFileReference", explicitFileType="wrapper.application", includeInIndex=0, path="Clay.app", sourceTree="BUILT_PRODUCTS_DIR")
        products.append(product)
        dependency = add("package-product:" + name, "XCSwiftPackageProductDependency", package=package, productName="ClayCore")
        framework = add("framework-build:" + name, "PBXBuildFile", productRef=dependency)
        source_members = []
        for path, ref in files.items():
            if path.startswith("Apps/Shared/") or path.startswith(f"Apps/{platform}/"):
                source_members.append(add(f"source:{name}:{path}", "PBXBuildFile", fileRef=ref))
        resource_members = [add(f"resource:{name}:{path}", "PBXBuildFile", fileRef=files[path])
                            for path in ["Resources/Fonts", "Resources/Assets.xcassets", "Resources/PrivacyInfo.xcprivacy"]]
        output_icons = [f"$(SRCROOT)/Resources/Assets.xcassets/AppIcon.appiconset/mac-{size}@{scale}x.png" for size in [16, 32, 128, 256, 512] for scale in [1, 2]]
        output_icons += ["$(SRCROOT)/Resources/Assets.xcassets/AppIcon.appiconset/ios-1024.png"]
        assets = add("assets:" + name, "PBXShellScriptBuildPhase", buildActionMask=2147483647, files=[], name="Prepare Clay app icons", inputPaths=["$(SRCROOT)/scripts/prepare_assets.swift", "$(SRCROOT)/Resources/Assets.xcassets/ClayMark.imageset/clay.png"], outputPaths=output_icons, runOnlyForDeploymentPostprocessing=0, shellPath="/bin/bash", shellScript='set -euo pipefail\nunset SDKROOT\n/usr/bin/xcrun --sdk macosx swift "$SRCROOT/scripts/prepare_assets.swift" "$SRCROOT"\n')
        sources = add("sources:" + name, "PBXSourcesBuildPhase", buildActionMask=2147483647, files=source_members, runOnlyForDeploymentPostprocessing=0)
        frameworks = add("frameworks:" + name, "PBXFrameworksBuildPhase", buildActionMask=2147483647, files=[framework], runOnlyForDeploymentPostprocessing=0)
        resources = add("resources:" + name, "PBXResourcesBuildPhase", buildActionMask=2147483647, files=resource_members, runOnlyForDeploymentPostprocessing=0)
        configs: list[str] = []
        for variant in ["Debug", "Release"]:
            settings = {
                "PRODUCT_NAME": "Clay",
                "PRODUCT_MODULE_NAME": "ClayMac" if platform == "macOS" else "ClayIOS",
                "INFOPLIST_FILE": f"Config/Info-{platform}.plist",
                "GENERATE_INFOPLIST_FILE": "NO",
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "NO",
                "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
                "SWIFT_EMIT_LOC_STRINGS": "YES",
                "SWIFT_STRICT_CONCURRENCY": "targeted",
                "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/../Frameworks" if platform == "macOS" else "@executable_path/Frameworks"],
                "SKIP_INSTALL": "NO",
            }
            if platform == "macOS":
                settings.update({"SDKROOT": "macosx", "SUPPORTED_PLATFORMS": "macosx", "MACOSX_DEPLOYMENT_TARGET": "14.0", "CODE_SIGN_ENTITLEMENTS": "Config/Clay-macOS.entitlements", "ENABLE_HARDENED_RUNTIME": "YES", "COMBINE_HIDPI_IMAGES": "YES"})
            else:
                settings.update({"SDKROOT": "iphoneos", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "TARGETED_DEVICE_FAMILY": "1,2", "SUPPORTS_MACCATALYST": "NO", "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO"})
            configs.append(add(f"config:{name}:{variant}", "XCBuildConfiguration", baseConfigurationReference=files["Config/Shared.xcconfig"], buildSettings=settings, name=variant))
        config_list = add("configs:" + name, "XCConfigurationList", buildConfigurations=configs, defaultConfigurationIsVisible=0, defaultConfigurationName="Release")
        target = add("target:" + name, "PBXNativeTarget", buildConfigurationList=config_list, buildPhases=[assets, sources, frameworks, resources], buildRules=[], dependencies=[], name=name, packageProductDependencies=[dependency], productName="Clay", productReference=product, productType="com.apple.product-type.application")
        targets.append(target)
        make_scheme(name, target)

    products_group = add("products-group", "PBXGroup", children=products, name="Products", sourceTree="<group>")
    shared_group = add("shared-group", "PBXGroup", children=[ref for path, ref in files.items() if path.startswith("Apps/Shared/")], name="Shared", sourceTree="<group>")
    mac_group = add("mac-group", "PBXGroup", children=[ref for path, ref in files.items() if path.startswith("Apps/macOS/")], name="macOS", sourceTree="<group>")
    ios_group = add("ios-group", "PBXGroup", children=[ref for path, ref in files.items() if path.startswith("Apps/iOS/")], name="iOS", sourceTree="<group>")
    other_group = add("other-group", "PBXGroup", children=[ref for path, ref in files.items() if not path.startswith("Apps/")], name="Resources and configuration", sourceTree="<group>")
    main_group = add("main-group", "PBXGroup", children=[shared_group, mac_group, ios_group, other_group, products_group], sourceTree="<group>")
    project_configs: list[str] = []
    for variant in ["Debug", "Release"]:
        settings = {
            "ALWAYS_SEARCH_USER_PATHS": "NO",
            "CLANG_ENABLE_MODULES": "YES",
            "CLANG_ENABLE_OBJC_ARC": "YES",
            "COPY_PHASE_STRIP": "NO",
            "GCC_C_LANGUAGE_STANDARD": "gnu17",
            "SWIFT_VERSION": "5.0",
            "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if variant == "Debug" else "-O",
            "DEBUG_INFORMATION_FORMAT": "dwarf" if variant == "Debug" else "dwarf-with-dsym",
            "ENABLE_TESTABILITY": "YES" if variant == "Debug" else "NO",
            "ONLY_ACTIVE_ARCH": "YES" if variant == "Debug" else "NO",
        }
        if variant == "Debug": settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG $(inherited)"
        else: settings["SWIFT_COMPILATION_MODE"] = "wholemodule"
        project_configs.append(add("project-config:" + variant, "XCBuildConfiguration", buildSettings=settings, name=variant))
    project_config_list = add("project-configs", "XCConfigurationList", buildConfigurations=project_configs, defaultConfigurationIsVisible=0, defaultConfigurationName="Release")
    project = add("project", "PBXProject", attributes={"BuildIndependentTargetsInParallel": "YES", "LastSwiftUpdateCheck": "2600", "LastUpgradeCheck": "2600", "TargetAttributes": {target: {"CreatedOnToolsVersion": "26.0", "ProvisioningStyle": "Automatic"} for target in targets}}, buildConfigurationList=project_config_list, compatibilityVersion="Xcode 14.0", developmentRegion="en", hasScannedForEncodings=0, knownRegions=["en", "Base"], mainGroup=main_group, packageReferences=[package], productRefGroup=products_group, projectDirPath="", projectRoot="", targets=targets)
    contents = {"archiveVersion": 1, "classes": {}, "objectVersion": 56, "objects": OBJECTS, "rootObject": project}
    output = ROOT / "Clay.xcodeproj/project.pbxproj"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("// !$*UTF8*$!\n" + serialize(contents) + "\n")
    workspace = ROOT / "Clay.xcodeproj/project.xcworkspace/contents.xcworkspacedata"
    workspace.parent.mkdir(parents=True, exist_ok=True)
    workspace.write_text('<?xml version="1.0" encoding="UTF-8"?>\n<Workspace version="1.0"><FileRef location="self:"></FileRef></Workspace>\n')

    # Structural validation of our own graph, not a substitute for xcodebuild.
    for obj in OBJECTS.values():
        for key in ["buildConfigurationList", "fileRef", "productRef", "productReference", "baseConfigurationReference", "mainGroup", "productRefGroup", "package"]:
            if key in obj: assert obj[key] in OBJECTS, (key, obj[key])
        for key in ["buildPhases", "files", "children", "buildConfigurations", "targets", "packageReferences", "packageProductDependencies"]:
            for ref in obj.get(key, []): assert ref in OBJECTS, (key, ref)
    for path in files: assert (ROOT / path).exists(), path
    assert all("Apps/" not in str(obj.get("path", "")) or str(obj["path"]).endswith(".swift") for obj in OBJECTS.values())
    print(f"Generated Clay.xcodeproj: {len(all_sources)} Swift app files, 2 application targets.")


if __name__ == "__main__":
    make_config()
    make_project()
