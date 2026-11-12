import NicheKit

@MainActor
protocol BuiltInActivity: AnyObject {
    func start(center: ActivityCenter)
}

@MainActor
enum BuiltInActivities {
    static func all() -> [any BuiltInActivity] {
        [
            AirPodsActivity()
        ]
    }
}
