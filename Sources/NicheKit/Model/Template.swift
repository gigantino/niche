import Foundation

extension JSONValue {
    func resolved(with context: JSONValue) -> JSONValue {
        switch self {
        case .array(let values):
            return .array(values.map { $0.resolved(with: context) })
        case .object(let values):
            return .object(values.mapValues { $0.resolved(with: context) })
        case .string(let template):
            guard template.contains("{{") else { return self }
            let parts = template.components(separatedBy: "{{")
            if parts.count == 2, parts[0].isEmpty, parts[1].hasSuffix("}}"), !parts[1].dropLast(2).contains("}}") {
                return context.lookup(String(parts[1].dropLast(2)))
            }

            var result = parts[0]
            for part in parts.dropFirst() {
                guard let end = part.range(of: "}}") else {
                    result += "{{" + part
                    continue
                }
                result += context.lookup(String(part[..<end.lowerBound])).text + part[end.upperBound...]
            }
            return .string(result)
        default:
            return self
        }
    }

    func mergingIsland(_ patch: JSONValue) -> JSONValue {
        guard case .object(var result) = self, case .object(let fields) = patch else { return patch }
        for (key, value) in fields {
            if key == "expanded", case .object(var regions)? = result[key], case .object(let changed) = value {
                regions.merge(changed) { _, new in new }
                result[key] = .object(regions)
            } else {
                result[key] = value
            }
        }
        return .object(result)
    }

    private func lookup(_ path: String) -> JSONValue {
        path.trimmingCharacters(in: .whitespaces).split(separator: ".").reduce(self) { value, key in
            guard case .object(let fields) = value else { return .null }
            return fields[String(key)] ?? .null
        }
    }

    private var text: String {
        switch self {
        case .null: ""
        case .bool(let value): String(value)
        case .number(let value): value == value.rounded() && abs(value) < 1e15 ? String(Int(value)) : String(value)
        case .string(let value): value
        case .array, .object: (try? JSONEncoder().encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        }
    }
}
