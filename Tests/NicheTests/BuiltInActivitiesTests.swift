import Foundation
import Testing
@testable import Niche

@MainActor
struct BuiltInActivitiesTests {
    static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/Niche/BuiltIn")

    @Test func everyBuiltInActivityInTheFolderIsRegistered() throws {
        let declaration = try Regex(#"(?:class|struct|actor)\s+(\w+)\s*:[^{]*\bBuiltInActivity\b"#)
        var declared: Set<String> = []
        for case let file as URL in FileManager.default.enumerator(at: Self.folder, includingPropertiesForKeys: nil)!
        where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            for match in source.matches(of: declaration) {
                declared.insert(String(match.output[1].substring ?? ""))
            }
        }
        let registered = Set(BuiltInActivities.all().map { String(describing: type(of: $0)) })

        #expect(!declared.isEmpty)
        #expect(declared == registered, "BuiltInActivities.all() must list every BuiltInActivity in Sources/Niche/BuiltIn")
    }
}
