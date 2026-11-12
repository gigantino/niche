import Foundation
import NicheKit
import Testing

struct DocumentationTests {
    let reference = try! String(contentsOfFile: Repository.path("API.md"), encoding: .utf8)

    @Test func theReferenceNamesEveryViewType() {
        for kind in Node.Kind.allCases {
            #expect(reference.contains("`\(kind.rawValue)`"), "API.md does not document the view \(kind.rawValue)")
        }
    }

    @Test func theReferenceNamesEveryOperation() {
        for operation in Request.Operation.allCases {
            #expect(reference.contains("\"op\":\"\(operation.rawValue)\""), "API.md does not document the op \(operation.rawValue)")
        }
    }

    @Test func theReferenceNamesEveryEvent() {
        for name in NotchEvent.Name.allCases {
            #expect(reference.contains("\"event\":\"\(name.rawValue)\""), "API.md does not document the event \(name.rawValue)")
        }
    }

    @Test func thePythonClientSendsOnlyKnownOperations() throws {
        let client = try String(contentsOfFile: Repository.path("Integrations/niche.py"), encoding: .utf8)
        let sent = client.matches(of: try Regex(#"self\.send\("(\w+)""#)).map { String($0.output[1].substring ?? "") }
        let known = Set(Request.Operation.allCases.map(\.rawValue))

        #expect(!sent.isEmpty)
        for operation in sent {
            #expect(known.contains(operation), "Integrations/niche.py sends the unknown op \(operation)")
        }
    }

    @Test func theReferenceNamesEveryIslandMode() {
        for mode in DynamicIslandMode.allCases {
            #expect(reference.contains("`\(mode.rawValue)`"), "API.md does not document the mode \(mode.rawValue)")
        }
    }
}
