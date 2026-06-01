//
//  ForbiddenImportTests.swift
//  EnglishHelperTests
//
//  Enforces the dependency rule: the Domain layer must stay pure — no platform/UI/transport
//  frameworks. Scans the Domain source files on disk (located via #filePath).
//

import Testing
import Foundation

@Suite struct ForbiddenImportTests {

    /// Frameworks the Domain must never import. Foundation (value types + JSON) is the sole allowance.
    static let forbiddenModules: Set<String> = [
        "SwiftUI", "UIKit", "AppKit", "AVFoundation", "AVFAudio", "Speech", "Vision",
        "CoreData", "SwiftData", "Combine", "Photos", "PhotosUI",
        "UniformTypeIdentifiers", "CoreImage", "CoreGraphics", "Network",
    ]

    static var domainDirectory: URL {
        URL(filePath: #filePath)            // …/Tests/ForbiddenImportTests.swift
            .deletingLastPathComponent()    // …/Tests
            .deletingLastPathComponent()    // repo root
            .appending(path: "Domain")
    }

    @Test func domainImportsOnlyAllowedFrameworks() throws {
        let files = try swiftFiles(in: Self.domainDirectory)
        #expect(!files.isEmpty, "Expected to find Domain source files at \(Self.domainDirectory.path)")

        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for rawLine in source.split(separator: "\n") {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                guard line.hasPrefix("import ") else { continue }
                let module = line.dropFirst("import ".count)
                    .split(separator: ".").first.map(String.init)?            // strip submodule
                    .trimmingCharacters(in: .whitespaces) ?? ""
                #expect(
                    !Self.forbiddenModules.contains(module),
                    "Domain/\(file.lastPathComponent) imports forbidden framework '\(module)'"
                )
            }
        }
    }

    @Test func domainDoesNotLeakTransportTypes() throws {
        for file in try swiftFiles(in: Self.domainDirectory) {
            let source = try String(contentsOf: file, encoding: .utf8)
            for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
                // Strip line comments so documentation that merely *names* these types doesn't trip the check.
                let code = rawLine.split(separator: "//", maxSplits: 1,
                                         omittingEmptySubsequences: false).first.map(String.init) ?? ""
                #expect(
                    !code.contains("URLSession"),
                    "Domain/\(file.lastPathComponent) references a transport type (URLSession) in code"
                )
            }
        }
    }

    private func swiftFiles(in directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }
        var result: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            result.append(url)
        }
        return result
    }
}
