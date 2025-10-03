import SwiftUI

private struct LowPerformanceKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var lowPerformance: Bool {
        get { self[LowPerformanceKey.self] }
        set { self[LowPerformanceKey.self] = newValue }
    }
}

extension View {
    func lowPerformance(_ value: Bool) -> some View {
        environment(\.lowPerformance, value)
    }
}
