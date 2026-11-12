import Foundation

func json(_ text: String, what: String) -> [String: Any] {
    guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
        fail("\(what) is not a JSON object")
    }
    return object
}

func file(_ path: String) -> String {
    guard let text = try? String(contentsOfFile: (path as NSString).expandingTildeInPath, encoding: .utf8) else {
        fail("cannot read \(path)")
    }
    return text
}

func object(_ argument: String, what: String) -> [String: Any] {
    json(argument.hasPrefix("@") ? file(String(argument.dropFirst())) : argument, what: what)
}

func time(_ argument: String, flag: String) -> Double {
    guard let value = Double(argument) else { fail("\(flag) needs Unix seconds or +SECONDS") }
    return argument.hasPrefix("+") ? Date().timeIntervalSince1970 + value : value
}

func set(_ value: Any, at path: [String], in target: inout [String: Any]) {
    guard path.count > 1 else {
        target[path[0]] = value
        return
    }
    var child = target[path[0]] as? [String: Any] ?? [:]
    set(value, at: Array(path.dropFirst()), in: &child)
    target[path[0]] = child
}

func request(_ op: String, id: String?, options: [String]) -> [String: Any] {
    var result: [String: Any] = ["op": op]
    var content: [String: Any] = [:]
    var island: [String: Any] = [:]
    var alert: [String: Any] = [:]
    var index = 0
    result["id"] = id

    func value(for flag: String) -> String {
        index += 1
        guard index < options.count else { fail("\(flag) needs a value") }
        return options[index]
    }

    while index < options.count {
        let flag = options[index]
        let key = String(flag.dropFirst(2))
        switch flag {
        case "--id":
            result["id"] = value(for: flag)
        case "--type":
            result["attributesType"] = value(for: flag)
        case "--attributes":
            result["attributes"] = object(value(for: flag), what: flag)
        case "--start", "--timestamp":
            result[key] = time(value(for: flag), flag: flag)
        case "--state":
            content["state"] = object(value(for: flag), what: flag)
        case "--staleDate":
            content["staleDate"] = time(value(for: flag), flag: flag)
        case "--relevanceScore":
            guard let score = Double(value(for: flag)) else { fail("\(flag) needs a number") }
            content["relevanceScore"] = score
        case "--compactLeading", "--compactTrailing", "--minimal":
            island[key] = node(value(for: flag))
        case "--leading", "--trailing", "--center", "--bottom":
            set(node(value(for: flag)), at: ["expanded", key], in: &island)
        case "--widgetURL":
            island[key] = value(for: flag)
        case "--dynamicIsland":
            island.merge(object(value(for: flag), what: flag)) { _, new in new }
        case "--alert":
            alert["title"] = value(for: flag)
        case "--body", "--sound":
            alert[key] = value(for: flag)
        case "--dismissalPolicy":
            let policy = value(for: flag)
            result[key] = policy.hasPrefix("after:")
                ? ["after": time(String(policy.dropFirst(6)), flag: flag)] as Any
                : policy
        default:
            fail("unknown option \(flag)")
        }
        index += 1
    }

    if !content.isEmpty { result["content"] = content }
    if !island.isEmpty { result["dynamicIsland"] = island }
    if !alert.isEmpty { result["alertConfiguration"] = alert }
    return result
}
