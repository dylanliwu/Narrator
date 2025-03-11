import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var isLabelReaderMode = false
    @State private var longHoldResult: String? = nil
    @State private var isButtonHeld = false
    @State private var hasHandledLongPress = false

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
                    Text(longHoldResult ?? viewModel.detectionResult.displayText)
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
                            longHoldResult = nil
                        }) {
                            ZStack {
                                Circle()
                                    .fill(isLabelReaderMode ? Color.blue : Color.white)
                                    .frame(width: 50, height: 50)
                                    .shadow(radius: 10)
                                
                                Text("📖")
                                    .font(.system(size: 24))
                            }
                        }
                        .frame(maxWidth: geometry.size.width * (1/3))
                        
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
                      
                        Button(action: {
                            viewModel.isVoiceModeEnabled.toggle()
                            longHoldResult = nil
                        }) {
                            ZStack {
                                Circle()
                                    .fill(viewModel.isVoiceModeEnabled ? Color.blue : Color.white)
                                    .frame(width: 50, height: 50)
                                    .shadow(radius: 10)
                                
                                Text("🎤")
                                    .font(.system(size: 24))
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

#Preview {
    ContentView()
}
