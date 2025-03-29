import SwiftUI

class AppSettings: ObservableObject {
    @Published var textColor: Color {
        didSet {
            AppSettings.saveColorToUserDefaults(textColor, key: "textColor")
        }
    }
    @Published var textSize: Double {
        didSet {
            UserDefaults.standard.set(textSize, forKey: "textSize")
        }
    }
    @Published var iconSize: Double {
        didSet {
            UserDefaults.standard.set(iconSize, forKey: "iconSize")
        }
    }
    @Published var buttonBackgroundColor: Color {
        didSet {
            AppSettings.saveColorToUserDefaults(buttonBackgroundColor, key: "buttonBackgroundColor")
        }
    }
    @Published var toggledButtonBackgroundColor: Color {
        didSet {
            AppSettings.saveColorToUserDefaults(toggledButtonBackgroundColor, key: "toggledButtonBackgroundColor")
        }
    }
    @Published var showingSettings: Bool = false
    @Published var prompts: [String] {
        didSet {
            UserDefaults.standard.set(prompts, forKey: "customPrompts")
        }
    }

    init() {
        textColor = AppSettings.loadColorFromUserDefaults(key: "textColor") ?? .white
        textSize = UserDefaults.standard.double(forKey: "textSize") == 0 ? 16.0 : UserDefaults.standard.double(forKey: "textSize")
        iconSize = UserDefaults.standard.double(forKey: "iconSize") == 0 ? 24.0 : UserDefaults.standard.double(forKey: "iconSize")
        buttonBackgroundColor = AppSettings.loadColorFromUserDefaults(key: "buttonBackgroundColor") ?? .white
        toggledButtonBackgroundColor = AppSettings.loadColorFromUserDefaults(key: "toggledButtonBackgroundColor") ?? .blue
        prompts = UserDefaults.standard.array(forKey: "customPrompts") as? [String] ?? Array(repeating: "Default Prompt", count: 6)
    }

    func resetToDefaults() {
        textColor = .white
        textSize = 16.0
        iconSize = 24.0
        buttonBackgroundColor = .white
        toggledButtonBackgroundColor = .blue
        prompts = Array(repeating: "Default Prompt", count: 6)
    }

    static func saveColorToUserDefaults(_ color: Color, key: String) {
        if let uiColor = UIColor(color).cgColor.components {
            UserDefaults.standard.set(uiColor, forKey: key)
        }
    }

    static func loadColorFromUserDefaults(key: String) -> Color? {
        if let components = UserDefaults.standard.array(forKey: key) as? [CGFloat], components.count >= 3 {
            return Color(red: Double(components[0]), green: Double(components[1]), blue: Double(components[2]))
        }
        return nil
    }
}
