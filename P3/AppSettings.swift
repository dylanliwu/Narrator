import SwiftUI

class AppSettings: ObservableObject {
    @Published var textColor: Color = .white
    @Published var textSize: Double = 16.0
    @Published var iconSize: Double = 24.0

    func resetToDefaults() {
        textColor = .white
        textSize = 16.0
        iconSize = 24.0
    }
}
