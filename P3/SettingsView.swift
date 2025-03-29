import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var originalSettings: AppSettings = AppSettings()

    var body: some View {
        NavigationView {
            Form {
                textAppearanceSection
                textSizeSection
                buttonSizeSection
                buttonBackgroundColorsSection
                customPromptsSection
                resetToDefaultsSection
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Discard") {
                        settings.textColor = originalSettings.textColor
                        settings.textSize = originalSettings.textSize
                        settings.iconSize = originalSettings.iconSize
                        settings.buttonBackgroundColor = originalSettings.buttonBackgroundColor
                        settings.toggledButtonBackgroundColor = originalSettings.toggledButtonBackgroundColor
                        settings.prompts = originalSettings.prompts
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                originalSettings = AppSettings()
                originalSettings.textColor = settings.textColor
                originalSettings.textSize = settings.textSize
                originalSettings.iconSize = settings.iconSize
                originalSettings.buttonBackgroundColor = settings.buttonBackgroundColor
                originalSettings.toggledButtonBackgroundColor = settings.toggledButtonBackgroundColor
                originalSettings.prompts = settings.prompts
            }
        }
    }

    private var textAppearanceSection: some View {
        Section(header: Text("Text Appearance")) {
            ColorPicker("Text Color", selection: $settings.textColor)
        }
    }

    private var textSizeSection: some View {
        Section(header: Text("Text Size")) {
            Slider(value: $settings.textSize, in: 12...24, step: 1) {
                Text("Text Size")
            }
        }
    }

    private var buttonSizeSection: some View {
        Section(header: Text("Button Size")) {
            Slider(value: $settings.iconSize, in: 16...40, step: 1) {
                Text("Icon Size")
            }
        }
    }

    private var buttonBackgroundColorsSection: some View {
        Section(header: Text("Button Background Colors")) {
            ColorPicker("Default Background", selection: $settings.buttonBackgroundColor)
            ColorPicker("Toggled Background", selection: $settings.toggledButtonBackgroundColor)
        }
    }

    private var customPromptsSection: some View {
        Section(header: Text("Custom Prompts")) {
            ForEach(0..<settings.prompts.count, id: \.self) { index in
                TextField("Prompt \(index + 1)", text: $settings.prompts[index])
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }

    private var resetToDefaultsSection: some View {
        Section {
            Button("Reset to Defaults") {
                settings.resetToDefaults()
            }
            .foregroundColor(.red)
        }
    }
}
