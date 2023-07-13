import Foundation
import Speech
import Combine

public class BSSpeechRecon: NSObject, SFSpeechRecognizerDelegate {
    var silenceTimer: Timer?
    var cancellables = Set<AnyCancellable>()
    
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
    
    public var stopSignal = PassthroughSubject<Void, Never>()
    
    public override init() {
        super.init()
        speechRecognizer.delegate = self

        stopSignal
            .sink { _ in
                self.audioEngine.stop()
                self.recognitionRequest?.endAudio()
                print("Listening has stopped!")
            }.store(in: &cancellables)
    }
    
    public func getSpeechRecognitionPermission() -> PassthroughSubject<SFSpeechRecognizerAuthorizationStatus, Never> {
        let permissionSubject: PassthroughSubject<SFSpeechRecognizerAuthorizationStatus, Never> = .init()
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            permissionSubject.send(authStatus)
        }
        
        return permissionSubject
    }
    
    private func resetSilenceTimer(shutDownTimer: Int) {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(shutDownTimer), repeats: false) { [weak self] _ in
            self?.stopSignal.send()
        }
    }

    public func startRecording(_ shutDownTimer: Int = 3) -> AnyPublisher<String, Never> {
        print("Listening has started!")
        let textSpeechSubject = PassthroughSubject<String, Never>()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest!.shouldReportPartialResults = true

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self = self else { return }
            var isFinal = false

            if let result = result {
                textSpeechSubject.send(result.bestTranscription.formattedString)
                isFinal = result.isFinal
                self.resetSilenceTimer(shutDownTimer: shutDownTimer)
            }

            if error != nil || isFinal {
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }

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
}
