// This fixture is concatenated with the actual transport source by
// scripts/test-sync-folder-paths.py so its private validation stays private.
private extension ClaySyncFolderWorker {
    func checkPathForFixture(_ url: URL, root: URL) throws {
        try validateAncestors(url, root: root)
    }

    func checkSourceForFixture(_ url: URL) throws {
        try rejectSourceFolder(url)
    }

    func checkDirectoryForFixture(_ url: URL) throws {
        try requireDirectory(url, root: url)
    }
}

@main
private struct ClaySyncFolderPathHarness {
    static func main() throws {
        setbuf(stdout, nil)
        let manager = FileManager.default
        let base = URL(fileURLWithPath: "/tmp/ClayFolderPathFixture-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: base) }
        let root = base.appendingPathComponent("PrivateClay", isDirectory: true)
        let inside = root.appendingPathComponent("ClaySync/Records", isDirectory: true)
        try manager.createDirectory(at: inside, withIntermediateDirectories: true)
        let canonicalRoot = URL(fileURLWithPath: "/private" + root.path, isDirectory: true)
        let canonicalInside = URL(fileURLWithPath: "/private" + inside.path, isDirectory: true)
        let worker = ClaySyncFolderWorker(deviceID: UUID())
        let expectAliasFailure = CommandLine.arguments.contains("--expect-alias-failure")
        var checks = 0

        func accepted(_ label: String, _ operation: () throws -> Void) throws {
            try operation()
            checks += 1
            print("PASS \(label)")
        }
        func rejected(_ label: String, _ operation: () throws -> Void) throws {
            do {
                try operation()
            } catch {
                checks += 1
                print("PASS \(label)")
                return
            }
            throw NSError(domain: "Clay.PathFixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Accepted unsafe path: \(label)"])
        }
        func ancestorAlias(_ label: String, url: URL, root: URL) throws {
            if expectAliasFailure {
                try rejected("Reproduced old alias failure: " + label) { try worker.checkPathForFixture(url, root: root) }
            } else {
                try accepted(label) { try worker.checkPathForFixture(url, root: root) }
            }
        }

        print("Selected spelling: \(root.path)")
        print("Coordinated spelling: \(canonicalRoot.path)")
        try accepted("/tmp root accepts /private/tmp child") { try worker.checkPathForFixture(canonicalInside, root: root) }
        try accepted("/private/tmp root accepts /tmp child") { try worker.checkPathForFixture(inside, root: canonicalRoot) }
        try accepted("coordinated selected-root spelling") { try worker.checkPathForFixture(canonicalRoot, root: root) }
        try accepted("uncreated descendant stays within alias root") { try worker.checkPathForFixture(canonicalInside.appendingPathComponent("new.json"), root: root) }
        let ancestor = base.appendingPathComponent("AncestorAlias", isDirectory: true)
        try manager.createSymbolicLink(at: ancestor, withDestinationURL: base)
        let aliasRoot = ancestor.appendingPathComponent("PrivateClay", isDirectory: true)
        let aliasInside = aliasRoot.appendingPathComponent("ClaySync/Records", isDirectory: true)
        try ancestorAlias("selected path has ancestor alias; coordinated path resolves it", url: canonicalInside, root: aliasRoot)
        try ancestorAlias("coordinated path has ancestor alias; selected path resolves it", url: aliasInside, root: canonicalRoot)
        try ancestorAlias("coordinated root after ancestor alias resolution", url: canonicalRoot, root: aliasRoot)
        try accepted("directory trailing slash") {
            let trailing = URL(fileURLWithPath: root.path + "/", isDirectory: true)
            try worker.checkPathForFixture(inside, root: trailing)
        }
        try accepted("picker-style URL with trailing slash") {
            let pickerURL = URL(string: root.absoluteString + "/")!
            try worker.checkPathForFixture(canonicalInside, root: pickerURL)
        }
        try rejected("sibling prefix escape") {
            try worker.checkPathForFixture(base.appendingPathComponent("PrivateClay-Other/record.json"), root: root)
        }
        let rootLink = base.appendingPathComponent("SelectedLink", isDirectory: true)
        try manager.createSymbolicLink(at: rootLink, withDestinationURL: root)
        try rejected("selected leaf symlink") {
            try worker.checkPathForFixture(rootLink, root: rootLink)
        }
        try rejected("coordinator resolving selected leaf cannot hide it") {
            try worker.checkPathForFixture(canonicalInside, root: rootLink)
        }
        let insideLink = root.appendingPathComponent("InsideLink", isDirectory: true)
        try manager.createSymbolicLink(at: insideLink, withDestinationURL: inside)
        try rejected("in-root symlink targeting same root") {
            try worker.checkPathForFixture(insideLink.appendingPathComponent("new.json"), root: root)
        }
        let outside = base.appendingPathComponent("Outside", isDirectory: true)
        try manager.createDirectory(at: outside, withIntermediateDirectories: false)
        let outsideLink = root.appendingPathComponent("OutsideLink", isDirectory: true)
        try manager.createSymbolicLink(at: outsideLink, withDestinationURL: outside)
        try rejected("in-root symlink targeting outside root") {
            try worker.checkPathForFixture(outsideLink.appendingPathComponent("new.json"), root: root)
        }
        let dangling = root.appendingPathComponent("Dangling", isDirectory: true)
        try manager.createSymbolicLink(at: dangling, withDestinationURL: base.appendingPathComponent("Absent"))
        try rejected("dangling in-root symlink") {
            try worker.checkPathForFixture(dangling.appendingPathComponent("new.json"), root: root)
        }
        let selectedFile = root.appendingPathComponent("file.md")
        try Data("Synthetic fixture".utf8).write(to: selectedFile)
        try rejected("ordinary file is not a private folder") {
            try worker.checkDirectoryForFixture(selectedFile)
        }
        let project = base.appendingPathComponent("[projects]/clay", isDirectory: true)
        try manager.createDirectory(at: project, withIntermediateDirectories: true)
        try rejected("Proton source project folder") { try worker.checkSourceForFixture(project) }
        let repo = base.appendingPathComponent("SourceRepo", isDirectory: true)
        try manager.createDirectory(at: repo.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try rejected("Git repository descendant") { try worker.checkSourceForFixture(repo.appendingPathComponent("private")) }
        let repoAlias = base.appendingPathComponent("SourceAlias", isDirectory: true)
        try manager.createSymbolicLink(at: repoAlias, withDestinationURL: repo)
        try rejected("alias ancestor into Git source") { try worker.checkSourceForFixture(repoAlias.appendingPathComponent("private")) }
        print("ALL \(checks) PATH VALIDATION CHECKS PASSED")
    }
}
