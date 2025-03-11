import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var isLabelReaderMode = false // Track label reader mode
    @State private var longHoldResult: String? = nil // Store long hold result
    @State private var isButtonHeld = false // Track if the button is being held
    @State private var hasHandledLongPress = false // Track if long press has been handled

    var body: some View {
        ZStack {
            if let frame = viewModel.currentFrame {
                Image(frame, scale: 1.0, label: Text("Camera Preview"))
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
            }

            GeometryReader { geometry in
                VStack {
                    Spacer()
                    Text(longHoldResult ?? viewModel.detectionResult.displayText) // Display long hold result if available
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .frame(maxWidth: geometry.size.width * 0.6)
                        .padding(.bottom, 20)
                        .fontWeight(.semibold)
                    
                    HStack {
                        // Label Reader Button
                        Button(action: {
                            isLabelReaderMode.toggle()
                            longHoldResult = nil // Reset long hold result when switching modes
                        }) {
                            ZStack {
                                Circle()
                                    .fill(isLabelReaderMode ? Color.blue : Color.white) // Change color based on mode
                                    .frame(width: 50, height: 50)
                                    .shadow(radius: 10)
                                
                                Text("📖")
                                    .font(.system(size: 24))
                            }
                        }
                        .frame(maxWidth: geometry.size.width * (1/3))
                        
                        // Photo Button
                        Button(action: {
                            // Handle tap action only if long press hasn't been handled
                            if !hasHandledLongPress {
                                longHoldResult = nil // Reset long hold result
                                if isLabelReaderMode {
                                    viewModel.analyzeCurrentFrame(with: "Read this and strictly return what it says, ignore any text that is not prominent, if you cannot read anything in the image output Nothing")
                                } else {
                                    viewModel.analyzeCurrentFrame() // Default analysis
                                }
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.8))
                                    .frame(width: 70, height: 70)
                                    .shadow(radius: 10)
                                    .opacity(isButtonHeld ? 0.5 : 1)
                                
                                Circle()
                                    .fill(Color.white.opacity(0.8))
                                    .frame(width: 60, height: 60)
                                    .opacity(isButtonHeld ? 0.5 : 1)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                            }
                        }
                        .buttonStyle(PlainButtonStyle()) // Use plain style to prevent default button behavior
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
                                        hasHandledLongPress = false // Reset long press handling
                                    }
                                }
                        )
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.75)
                                .onEnded { _ in
                                    // Handle long press action
                                    hasHandledLongPress = true
                                    viewModel.analyzeCurrentFrame(with: "State the 1 most prominent object in the image. Simply return the object itself. If you cannot read anything in the image return Nothing")
                                }
                        )
                        
                        // Voice Mode Button
                        Button(action: {
                            viewModel.isVoiceModeEnabled.toggle()
                            longHoldResult = nil // Reset long hold result when switching modes
                        }) {
                            ZStack {
                                Circle()
                                    .fill(viewModel.isVoiceModeEnabled ? Color.blue : Color.white) // Change color based on mode
                                    .frame(width: 50, height: 50)
                                    .shadow(radius: 10)
                                
                                Text("🎤")
                                    .font(.system(size: 24))
                            }
                        }
                        .frame(maxWidth: geometry.size.width * (1/3))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20) // Add horizontal padding to center the buttons
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            viewModel.startCapture()
        }
        .onDisappear {
            viewModel.stopCapture()
        }
        .onChange(of: viewModel.detectionResult) { oldValue, newValue in
            // Store the result of the long hold analysis
            if case .labelReadingSuccess(let result) = newValue {
                longHoldResult = result
            }
        }
    }
}

#Preview {
    ContentView()
}
