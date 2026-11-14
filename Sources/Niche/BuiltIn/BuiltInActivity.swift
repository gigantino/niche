import NicheKit

@MainActor
protocol BuiltInActivity: AnyObject {
    func start(center: ActivityCenter, notch: NotchModel)
}

@MainActor
enum BuiltInActivities {
    static func all() -> [any BuiltInActivity] {
        [
            AirPodsActivity(),
            MediaActivity()
        ]
    }
}
