import AVFoundation
import CoreImage
import GoogleGenerativeAI
import UIKit
import SwiftUI
import Combine

// MARK: - CameraViewModel

class CameraViewModel: ObservableObject {
    @Published var currentFrame: CGImage?
    @Published var detectionResult: DetectionResult = .initializing
    @Published var isVoiceModeEnabled: Bool = true // Voice Mode enabled by default
    
    private let cameraManager: CameraManager
    private let visionAnalyzer: VisionAnalyzer
    private var cancellables = Set<AnyCancellable>()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    init() {
        self.cameraManager = CameraManager()
        self.visionAnalyzer = VisionAnalyzer()
        
        cameraManager.$currentFrame
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newFrame in
                self?.currentFrame = newFrame
            }
            .store(in: &cancellables)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.detectionResult = .ready
        }
    }
    
    func analyzeCurrentFrame(with customPrompt: String? = nil) {
        guard let currentFrame = self.currentFrame else { return }
        self.detectionResult = .ready
        if case .ready = self.detectionResult {
            self.analyzeFrame(currentFrame, with: customPrompt)
        }
    }
    
    private func analyzeFrame(_ frame: CGImage, with customPrompt: String?) {
        detectionResult = .processing
        let visionAnalyzer = self.visionAnalyzer
        Task { [weak self] in
            do {
                let result = try await visionAnalyzer.analyzeImage(frame, with: customPrompt)
                await MainActor.run { [weak self] in
                    self?.detectionResult = result
                    if self?.isVoiceModeEnabled == true { // Only speak if Voice Mode is enabled
                        self?.speakPrompt(result.displayText)
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.detectionResult = .error("Error: \(error.localizedDescription)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                        self?.detectionResult = .ready
                    }
                }
            }
        }
    }
    
    private func speakPrompt(_ text: String) {
        do {
            // Set the audio session category to playback (ignores the silent switch)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error.localizedDescription)")
        }

        // Stop any ongoing speech before starting a new one
        speechSynthesizer.stopSpeaking(at: .immediate)

        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechSynthesizer.speak(speechUtterance)
    }
    
    func startCapture() {
        cameraManager.startCapture()
    }
    
    func stopCapture() {
        cameraManager.stopCapture()
    }
    
    deinit {
        stopCapture()
        speechSynthesizer.stopSpeaking(at: .immediate) // Stop TTS when the ViewModel is deinitialized
    }
}

// MARK: - CameraManager
class CameraManager: NSObject, ObservableObject {
    @Published var currentFrame: CGImage?
    
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.camera.sessionQueue", qos: .userInitiated)
    private let processingQueue = DispatchQueue(label: "com.camera.processingQueue", qos: .userInteractive)
    private let context = CIContext()
    
    override init() {
        super.init()
        setupSession()
    }
    
    func startCapture() {
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func stopCapture() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.checkCameraPermission { granted in
                guard granted else {
                    print("Camera permission denied")
                    return
                }
                self.configureSession()
            }
        }
    }
    
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        guard let camera = getBestCamera(),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Failed to create camera input")
            return
        }
        
        guard captureSession.canAddInput(input) else {
            print("Cannot add camera input to session")
            return
        }
        captureSession.addInput(input)
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        guard captureSession.canAddOutput(videoOutput) else {
            print("Cannot add video output to session")
            return
        }
        captureSession.addOutput(videoOutput)
        
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if camera.position == .front && connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
        
        captureSession.sessionPreset = .medium
    }
    
    private func getBestCamera() -> AVCaptureDevice? {
        if let ultraWideCamera = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            return ultraWideCamera
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.currentFrame = cgImage
        }
    }
}

// MARK: - VisionAnalyzer
class VisionAnalyzer {
    private var generativeModel: GenerativeModel?
    
    init() {
        setupModel()
    }
    
    private func setupModel() {
        let apiKey = "AIzaSyCn9Zyj1ImouUwoaPs0B5uV6lI3dpgRTZ0"
        generativeModel = GenerativeModel(name: "gemini-1.5-flash", apiKey: apiKey)
        print("Generative model initialized with hardcoded API key")
    }
    
    func analyzeImage(_ image: CGImage, with customPrompt: String? = nil) async throws -> DetectionResult {
        guard let model = generativeModel else {
            throw VisionError.modelNotInitialized
        }
        
        let uiImage = UIImage(cgImage: image)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.7) else {
            throw VisionError.imageConversionFailed
        }
        
        let imagePart = ModelContent.Part.jpeg(jpegData)
        let prompt = customPrompt ?? """
        Identify objects in this image. Return the response STRICTLY in this format:

        Objects: [comma-separated list of objects].
        
        Environment: [one-sentence description]
        
        If you see multiple objects that are the same, always group them with a quantity adjective.

        NO additional text. If no objects are detected, return Nothing.
        """
        
        let response = try await model.generateContent(prompt, imagePart)
        guard let responseText = response.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw VisionError.noResponseFromModel
        }
        
        if customPrompt != nil {
            return .labelReadingSuccess(responseText)
        } else {
            return .success(parseResponse(responseText))
        }
    }
    
    private func parseResponse(_ response: String) -> VisionResult {
        var objects: [String] = []
        var environment: String = ""
        let lines = response.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("Objects:") {
                let objectsString = line.replacingOccurrences(of: "Objects:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if objectsString != "None" {
                    objects = objectsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                }
            } else if line.hasPrefix("Environment:") {
                environment = line.replacingOccurrences(of: "Environment:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return VisionResult(objects: objects, environment: environment)
    }
    
    enum VisionError: Error {
        case modelNotInitialized
        case imageConversionFailed
        case noResponseFromModel
    }
}

// MARK: - VisionResult
struct VisionResult {
    let objects: [String]
    let environment: String
    
    var description: String {
        let objectsText = objects.isEmpty ? "None" : objects.joined(separator: ", ")
        return "Objects: \(objectsText)\nEnvironment: \(environment)"
    }
}

// MARK: - DetectionResult
enum DetectionResult: Equatable {
    case initializing
    case ready
    case processing
    case success(VisionResult)
    case labelReadingSuccess(String)
    case error(String)
    
    var displayText: String {
        switch self {
        case .initializing:
            return "Initializing"
        case .ready:
            return "Ready"
        case .processing:
            return "Processing"
        case .success(let result):
            return result.description
        case .labelReadingSuccess(let labelText):
            return labelText
        case .error(let message):
            return message
        }
    }
    
    // Implement Equatable conformance
    static func == (lhs: DetectionResult, rhs: DetectionResult) -> Bool {
        switch (lhs, rhs) {
        case (.initializing, .initializing),
             (.ready, .ready),
             (.processing, .processing):
            return true
        case (.success(let lhsResult), .success(let rhsResult)):
            return lhsResult.objects == rhsResult.objects && lhsResult.environment == rhsResult.environment
        case (.labelReadingSuccess(let lhsText), .labelReadingSuccess(let rhsText)):
            return lhsText == rhsText
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}
