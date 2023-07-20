import Foundation
import Speech
import Combine

public class BSSpeechRecon: NSObject, SFSpeechRecognizerDelegate {
    private var silenceTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var isFinal = false
    
    private let speechRecognizer: SFSpeechRecognizer = {
        if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: Locale.current.identifier)),
           recognizer.isAvailable {
            return recognizer
        } else {
            let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
            print("Speech recognizer is not available for the current locale. Using American English")
            return speechRecognizer
        }
    }()
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    /// A variable that holds a Combine signal to get the service stop information reactively.
    public var stopSignal = PassthroughSubject<Void, Never>()
    
    public override init() {
        super.init()
        speechRecognizer.delegate = self
        
        stopSignal
            .sink { _ in
                self.audioEngine.stop()
                self.recognitionRequest?.endAudio()
            }.store(in: &cancellables)
    }
    
    /// Method to get user speech recognition authorization.
    /// - Returns: User's authorization status.
    public func getSpeechRecognitionPermission() -> PassthroughSubject<SFSpeechRecognizerAuthorizationStatus, Never> {
        let permissionSubject: PassthroughSubject<SFSpeechRecognizerAuthorizationStatus, Never> = .init()
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            permissionSubject.send(authStatus)
        }
        
        return permissionSubject
    }
    
    /// Method to start listening for user's speech.
    /// - Parameter shutDownTimer: Seconds that the user can be quit without stopping the service.
    /// - Returns: A Combine publisher that holds the user speech transcribed in a string.
    public func startListening(_ shutDownTimer: Int = 3) -> AnyPublisher<String, Never> {
        let textSpeechSubject = PassthroughSubject<String, Never>()
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest!.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                textSpeechSubject.send(result.bestTranscription.formattedString)
                self.isFinal = result.isFinal
                self.resetSilenceTimer(shutDownTimer: shutDownTimer != 0 ? shutDownTimer : 300)
            }
            
            if error != nil || self.isFinal {
                self.stopListening()
            }
        }
        
        startAudioEngine()
        
        let silencePublisher = textSpeechSubject
            .handleEvents(receiveSubscription: { _ in
                self.resetSilenceTimer(shutDownTimer: shutDownTimer)
            }, receiveCompletion: { _ in
                self.silenceTimer?.invalidate()
                self.silenceTimer = nil
            }, receiveCancel: {
                self.silenceTimer?.invalidate()
                self.silenceTimer = nil
            })
        
        return silencePublisher
            .eraseToAnyPublisher()
    }
    
    /// Method to stop the listening process. Emits a signal to inform that the service has ended.
    public func stopListening() {
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
        
        self.recognitionRequest = nil
        self.recognitionTask = nil
        
        stopSignal.send(())
    }
    
    private func startAudioEngine() {
        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error.localizedDescription)")
        }
    }
    
    private func resetSilenceTimer(shutDownTimer: Int) {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(shutDownTimer), repeats: false) { [weak self] _ in
//            self?.stopListening()
            self?.isFinal = false
        }
    }
}
