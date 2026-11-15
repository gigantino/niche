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
}
