import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Text Appearance")) {
                    ColorPicker("Text Color", selection: $settings.textColor)
                }
                
                Section(header: Text("Text Size")) {
                    Slider(value: $settings.textSize, in: 12...24, step: 1) {
                        Text("Text Size")
                    }
                }
                Section(header: Text("Button Size")) {
                    Slider(value: $settings.iconSize, in: 16...40, step: 1) {
                        Text("Icon Size")
                    }
                }

                Section {
                    Button("Reset to Defaults") {
                        settings.resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
