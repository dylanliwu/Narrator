import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()
    @StateObject private var settings = AppSettings()
    @State private var isLabelReaderMode = false
    @State private var longHoldResult: String? = nil
    @State private var isButtonHeld = false
    @State private var hasHandledLongPress = false
    @State private var showingSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background: Show frame or placeholder
                Group {
                    if let frame = viewModel.currentFrame {
                        // Properly display CGImage using UIImage
                        Image(uiImage: UIImage(cgImage: frame))
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea()
                    } else {
                        Color.black
                            .ignoresSafeArea()
                    }
                }

                // UI Overlay
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        
                        // Display detection result or long press result
                        Text(longHoldResult ?? viewModel.detectionResult.displayText)
                            .font(.system(size: settings.textSize))
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(settings.textColor)
                            .cornerRadius(10)
                            .frame(maxWidth: geometry.size.width * 0.6)
                            .padding(.bottom, 20)
                            .fontWeight(.semibold)

                        // Action Buttons
                        HStack {
                            // Label Reader Toggle
                            Button(action: {
                                isLabelReaderMode.toggle()
                                longHoldResult = nil
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(isLabelReaderMode ? Color.blue : Color.white)
                                        .frame(width: settings.iconSize * 2, height: settings.iconSize * 2)
                                        .shadow(radius: 10)

                                    Text("📖")
                                        .font(.system(size: settings.iconSize))
                                }
                            }
                            .frame(maxWidth: geometry.size.width * (1/3))

                            // Analyze Button (Tap & Long Press)
                            Button(action: {
                                if !hasHandledLongPress {
                                    longHoldResult = nil
                                    if isLabelReaderMode {
                                        viewModel.analyzeCurrentFrame(with: "Read this and strictly return what it says, ignore any text that is not prominent, if you cannot read anything in the image output Nothing")
                                    } else {
                                        viewModel.analyzeCurrentFrame()
                                    }
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: settings.iconSize * 2.5, height: settings.iconSize * 2.5)
                                        .shadow(radius: 10)
                                        .opacity(isButtonHeld ? 0.5 : 1)

                                    Circle()
                                        .stroke(Color.black, lineWidth: 2)
                                        .frame(width: settings.iconSize * 2.2, height: settings.iconSize * 2.2)
                                        .opacity(isButtonHeld ? 0.5 : 1)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isButtonHeld = true
                                        }
                                    }
                                    .onEnded { _ in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isButtonHeld = false
                                            hasHandledLongPress = false
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.75)
                                    .onEnded { _ in
                                        hasHandledLongPress = true
                                        viewModel.analyzeCurrentFrame(with: "State the 1 most prominent object in the image. Simply return the object itself. If you cannot read anything in the image return Nothing")
                                    }
                            )

                            // Voice Toggle
                            Button(action: {
                                viewModel.isVoiceModeEnabled.toggle()
                                longHoldResult = nil
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(viewModel.isVoiceModeEnabled ? Color.blue : Color.white)
                                        .frame(width: settings.iconSize * 2, height: settings.iconSize * 2)
                                        .shadow(radius: 10)

                                    Text("🎤")
                                        .font(.system(size: settings.iconSize))
                                }
                            }
                            .frame(maxWidth: geometry.size.width * (1/3))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: min(settings.iconSize, 24)))
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(settings: settings)
            }
            .onAppear {
                viewModel.startCapture()
            }
            .onDisappear {
                viewModel.stopCapture()
            }
            .onChange(of: viewModel.detectionResult) { oldValue, newValue in
                if case .labelReadingSuccess(let result) = newValue {
                    longHoldResult = result
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
