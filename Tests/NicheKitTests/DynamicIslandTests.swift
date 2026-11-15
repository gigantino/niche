import Foundation
import NicheKit
import Testing

struct DynamicIslandTests {
    @Test func paddingTakesANumberAPairOrFourValues() throws {
        let decoded = try island("""
        {"compactLeading": {"type": "Text", "padding": 4},
         "compactTrailing": {"type": "Text", "padding": [6, 2]},
         "minimal": {"type": "Text", "padding": [1, 2, 3, 4]}}
        """)

        #expect(decoded.compactLeading?.padding == Insets(top: 4, leading: 4, bottom: 4, trailing: 4))
        #expect(decoded.compactTrailing?.padding == Insets(top: 2, leading: 6, bottom: 2, trailing: 6))
        #expect(decoded.minimal?.padding == Insets(top: 1, leading: 2, bottom: 3, trailing: 4))
        #expect(throws: DecodingError.self) { try island(#"{"minimal": {"type": "Text", "padding": [1, 2, 3]}}"#) }
    }

    @Test func contentMarginsApplyInOrderToTheirMode() throws {
        let decoded = try island("""
        {"contentMargins": [
            {"length": 10, "for": "expanded"},
            {"edges": "horizontal", "length": 20, "for": "expanded"},
            {"edges": "top", "length": 1, "for": "expanded"},
            {"edges": "leading", "length": 14, "for": "compactLeading"},
            {"edges": "vertical", "length": 2, "for": "minimal"}
        ]}
        """)
        let fallback = Insets(top: 0, leading: 18, bottom: 18, trailing: 18)

        #expect(decoded.margins(for: .expanded, default: fallback) == Insets(top: 1, leading: 20, bottom: 10, trailing: 20))
        #expect(decoded.margins(for: .compactLeading, default: Insets(leading: 8, trailing: 3)) == Insets(leading: 14, trailing: 3))
        #expect(decoded.margins(for: .minimal, default: Insets()) == Insets(top: 2, bottom: 2))
        #expect(decoded.margins(for: .compactTrailing, default: fallback) == fallback)
    }

    @Test func theAttachedViewFallsBackFromMinimalToCompact() throws {
        #expect(try island(#"{"minimal": {"type": "Spacer"}, "compactLeading": {"type": "Text"}}"#).attached?.type == .spacer)
        #expect(try island(#"{"compactLeading": {"type": "Text"}, "compactTrailing": {"type": "Image"}}"#).attached?.type == .text)
        #expect(try island(#"{"compactTrailing": {"type": "Image"}}"#).attached?.type == .image)
        #expect(try island("{}").attached == nil)
    }
}
