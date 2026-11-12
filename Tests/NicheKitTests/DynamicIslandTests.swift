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

    @Test func frameMaximaTakeANumberOrInfinity() throws {
        let frame = try island(#"{"minimal": {"type": "Text", "frame": {"maxWidth": "infinity", "maxHeight": 30}}}"#)
            .minimal?.frame

        #expect(frame?.maxWidth == .infinity)
        #expect(frame?.maxWidth?.value == .infinity)
        #expect(frame?.maxHeight == .points(30))
        #expect(throws: DecodingError.self) {
            try island(#"{"minimal": {"type": "Text", "frame": {"maxWidth": "wide"}}}"#)
        }
    }

    @Test func fontTakesATextStyleOrAnObject() throws {
        let decoded = try island("""
        {"compactLeading": {"type": "Text", "font": "headline"},
         "compactTrailing": {"type": "Text", "font": {"size": 13, "weight": "bold", "design": "rounded"}}}
        """)

        #expect(decoded.compactLeading?.font == FontSpec(style: "headline"))
        #expect(decoded.compactTrailing?.font == FontSpec(size: 13, weight: "bold", design: "rounded"))
    }

    @Test func aViewNeedsAKnownType() {
        #expect(throws: DecodingError.self) { try island(#"{"minimal": {"type": "Nope"}}"#) }
        #expect(throws: DecodingError.self) { try island(#"{"minimal": {"text": "x"}}"#) }
    }

    @Test func unknownFieldsAreIgnored() throws {
        let decoded = try island(#"{"keylineTint": "red", "minimal": {"type": "Text", "sparkle": true}}"#)
        #expect(decoded.minimal?.type == .text)
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

    @Test func anIslandIsExpandableOnlyWithAtLeastOneRegion() throws {
        #expect(try island(#"{"expanded": {}}"#).hasExpanded == false)
        #expect(try island(#"{"expanded": {"bottom": {"type": "Spacer"}}}"#).hasExpanded == true)
    }

    @Test func ifAndUnlessDecideVisibility() throws {
        let decoded = try island("""
        {"compactLeading": {"type": "Text", "if": false},
         "compactTrailing": {"type": "Text", "unless": true},
         "minimal": {"type": "Text", "if": true, "unless": false}}
        """)

        #expect(decoded.compactLeading?.isVisible == false)
        #expect(decoded.compactTrailing?.isVisible == false)
        #expect(decoded.minimal?.isVisible == true)
    }

    @Test func dismissalPolicyReadsApplesThreeForms() throws {
        func policy(_ json: String) throws -> DismissalPolicy {
            try JSONDecoder().decode(DismissalPolicy.self, from: Data(json.utf8))
        }

        #expect(try policy(#""default""#) == .default)
        #expect(try policy(#""immediate""#) == .immediate)
        #expect(try policy(#"{"after": 1794500600}"#) == .after(1794500600))
        #expect(throws: DecodingError.self) { try policy(#""later""#) }
    }
}
