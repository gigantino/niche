import IOBluetooth
import NicheKit

struct AirPods: Equatable {
    enum Model {
        case standard, thirdGeneration, fourthGeneration, pro, proSecondGeneration, max

        var symbol: String {
            switch self {
            case .standard: "airpods"
            case .thirdGeneration, .fourthGeneration: "airpods.gen3"
            case .pro, .proSecondGeneration: "airpods.pro"
            case .max: "airpods.max"
            }
        }

        var video: URL? {
            let name: String? = switch self {
            case .standard: nil
            case .thirdGeneration: "airpods-3"
            case .fourthGeneration: "airpods-4"
            case .pro: "airpods-pro"
            case .proSecondGeneration: "airpods-pro-2"
            case .max: "airpods-max-silver"
            }
            return name.flatMap { Bundle.main.url(forResource: $0, withExtension: "mp4") }
        }
    }

    let id: String
    let model: Model
    var battery: Int?

    var island: DynamicIsland {
        Self.island(video: model.video, symbol: model.symbol, battery: battery)
    }

    static func island(video: URL?, symbol: String, battery: Int?) -> DynamicIsland {
        let artwork = video.map { video in
            Node(.video) {
                $0.source = video.path
                $0.padding = Insets(bottom: 2, trailing: -1)
            }
        } ?? Node(.image) {
            $0.systemName = symbol
            $0.font = FontSpec(size: 17, weight: "medium")
            $0.padding = Insets(leading: 4, trailing: 5)
        }
        let ring = Node(.progressView) {
            $0.value = Double(battery ?? 0) / 100
            $0.progressViewStyle = "circular"
            $0.tint = (battery ?? 100) <= 20 ? "#FF6366" : "#7BF1A8"
            $0.frame = Frame(width: 17.5, height: 17.5)
            $0.padding = Insets(leading: 8.25, trailing: 5.25)
        }
        return DynamicIsland(
            compactLeading: artwork,
            compactTrailing: ring,
            minimal: artwork,
            contentMargins: [
                DynamicIsland.ContentMargins(edges: "leading", length: 6, for: .compactLeading),
                DynamicIsland.ContentMargins(edges: "trailing", length: 0, for: .compactLeading),
                DynamicIsland.ContentMargins(edges: "leading", length: 0, for: .compactTrailing),
                DynamicIsland.ContentMargins(edges: "trailing", length: 6, for: .compactTrailing)
            ]
        )
    }

    init?(device: IOBluetoothDevice) {
        let name = (device.name ?? "").lowercased()
        let vendor = Self.number(device, "vendorID")
        let product = Self.number(device, "productID")

        let known: Model? = switch (vendor, product) {
        case (0x004C, 0x2002), (0x004C, 0x200F): .standard
        case (0x004C, 0x2013): .thirdGeneration
        case (0x004C, 0x2019), (0x004C, 0x201B): .fourthGeneration
        case (0x004C, 0x200E): .pro
        case (0x004C, 0x2014), (0x004C, 0x2024): .proSecondGeneration
        case (0x004C, 0x200A), (0x004C, 0x201F): .max
        default: nil
        }

        if let known {
            model = known
        } else if name.contains("airpods") {
            model = name.contains("max") ? .max : name.contains("pro") ? .proSecondGeneration : .standard
        } else {
            return nil
        }

        id = device.addressString ?? name
        battery = Self.battery(of: device)
    }

    static func battery(of device: IOBluetoothDevice) -> Int? {
        let buds = ["batteryPercentLeft", "batteryPercentRight"]
            .compactMap { number(device, $0) }
            .filter { $0 > 0 }
        if let lowest = buds.min() { return lowest }

        return ["batteryPercentSingle", "batteryPercentCombined"]
            .compactMap { number(device, $0) }
            .first { $0 > 0 }
    }

    private static func number(_ device: IOBluetoothDevice, _ key: String) -> Int? {
        guard device.responds(to: NSSelectorFromString(key)) else { return nil }
        return (device.value(forKey: key) as? NSNumber)?.intValue
    }
}
