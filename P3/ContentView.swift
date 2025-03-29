import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()
    @StateObject private var settings = AppSettings()
    @State private var isPromptPopupVisible = false
    @State private var selectedPromptIndex: Int? = nil
    @State private var longHoldResult: String? = nil
    @State private var isButtonHeld = false
    @State private var hasHandledLongPress = false
    @State private var preventTapAfterLongPress = false
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var isFlashOn = false

    private let defaultPrompt = """
    Identify objects in this image. Return the response STRICTLY in this format:

    Objects: [comma-separated list of objects].
    
    Environment: [one-sentence description]
    
    If you see multiple objects that are the same, always group them with a quantity adjective.

    NO additional text. If no objects are detected, return Nothing.
    """

    private let prominentObjectPrompt = """
    State the 1 most prominent object in the image. Simply return the object itself. If you cannot read anything in the image return Nothing.
    """

    var body: some View {
        NavigationView {
            ZStack {
                Group {
                    if let frame = viewModel.currentFrame {
                        Image(uiImage: UIImage(cgImage: frame))
                            .resizable()
                            .scaledToFill()
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastZoomScale
                                        lastZoomScale = value
                                        let newZoomFactor = viewModel.cameraManager.lastZoomFactor * delta
                                        viewModel.cameraManager.setZoomFactor(newZoomFactor)
                                    }
                                    .onEnded { _ in
                                        lastZoomScale = 1.0
                                    }
                            )
                            .ignoresSafeArea()
                    } else {
                        Color.black
                            .ignoresSafeArea()
                    }
                }

                GeometryReader { geometry in
                    VStack {
                        Spacer()

                        Text(longHoldResult ?? viewModel.detectionResult.displayText)
                            .font(.system(size: settings.textSize))
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(settings.textColor)
                            .cornerRadius(10)
                            .frame(maxWidth: geometry.size.width * 0.8)
                            .padding(.bottom, 20)
                            .fontWeight(.semibold)

                        HStack {
                            Button(action: {
                                isPromptPopupVisible.toggle()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(isPromptPopupVisible ? settings.toggledButtonBackgroundColor : settings.buttonBackgroundColor)
                                        .frame(width: settings.iconSize * 2, height: settings.iconSize * 2)
                                        .shadow(radius: 10)

                                    Text("📋")
                                        .font(.system(size: settings.iconSize))
                                }
                            }
                            .popover(isPresented: $isPromptPopupVisible) {
                                VStack {
                                    ForEach(0..<settings.prompts.count, id: \.self) { index in
                                        Button(action: {
                                            if selectedPromptIndex == index {
                                                selectedPromptIndex = nil
                                            } else {
                                                selectedPromptIndex = index
                                            }
                                        }) {
                                            Text(settings.prompts[index])
                                                .padding()
                                                .frame(maxWidth: .infinity)
                                                .background(selectedPromptIndex == index ? Color.blue : Color.gray.opacity(0.2))
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding()
                                .frame(width: 200)
                            }
                            .frame(maxWidth: geometry.size.width * (1/3))

                            Button(action: {
                                if !preventTapAfterLongPress {
                                    longHoldResult = nil
                                    let promptToUse = selectedPromptIndex != nil ? settings.prompts[selectedPromptIndex!] : defaultPrompt
                                    viewModel.analyzeCurrentFrame(with: promptToUse)
                                }
                                preventTapAfterLongPress = false
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(isButtonHeld ? settings.toggledButtonBackgroundColor : settings.buttonBackgroundColor)
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
                                        preventTapAfterLongPress = true
                                        longHoldResult = nil
                                        viewModel.analyzeCurrentFrame(with: prominentObjectPrompt)
                                    }
                            )

                            Button(action: {
                                viewModel.isVoiceModeEnabled.toggle()
                                longHoldResult = nil
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(viewModel.isVoiceModeEnabled ? settings.toggledButtonBackgroundColor : settings.buttonBackgroundColor)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isFlashOn.toggle()
                        viewModel.cameraManager.toggleFlashMode()
                    }) {
                        Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        settings.showingSettings = true
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $settings.showingSettings) {
                SettingsView(settings: settings)
            }
            .onAppear {
                viewModel.startCapture()
            }
            .onDisappear {
                viewModel.stopCapture()
            }
        }
    }
}
