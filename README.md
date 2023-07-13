# BSSpeechRecon

## The ultimate package to get your speech in text for iOS powered by Combine!

### Instalation:
The way of installing DependencyInversionHelper is via the Swift Package Manager (Xcode 12 or higher).

1. In Xcode, open your project and navigate to File → Swift Packages → Add Package Dependency...
2. Paste the repository URL (https://github.com/DarioSantor/BSSpeechRecon.git) and click Next.
3. For Rules, select Version (Up to Next Minor) and click Next.
4. Click Finish.

### Usage:
This package has 3 functions:

* getSpeechRecognitionPermission()
* startListening()
* stopListening()

### In a practical example:

Import BSSpeechRecon:
```swift
import BSSpeechRecon
```

Instantiate the package class:
```swift
var speechService = BSSpeechRecon()
```

Ask for user's permission:
> Update the plist file adding:

>> Privacy - Speech Recognition Usage Description - Give it an explanation for the permission in value field.

> Ask for the user's permission only you need it and then take care of the response as it will return a PassthroughSubject<SFSpeechRecognizerAuthorizationStatus, Never>;

Example:
``` swift
@objc func doSomething() {
    speechService.getSpeechRecognitionPermission()
        .sink { authStatus in
            switch authStatus {
                case .authorized:
                    self.startListening() // here we can call a method to start listening for user's speech
                    
                case .denied:
                    print("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    print("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    print("Speech recognition not yet authorized", for: .disabled)
                    
                @unknown default:
                    print("Speech recognition not yet authorized", for: .disabled)
            }
        }
    }.store(in: &cancellables)
}
```

Get the text:
> Now we can start listening for user's speech and get it asynchronously thanks to Combine:
```swift
func startListening() {
    speechService.startListening()
        .sink { textSpeeched in
            self.textView.text = textSpeeched
        }.store(in: &cancellables)
}
```

> The default shutdown time it's 3 seconds but you can change it passing a different value;
> If you give the shutdown a value of 0 it it will listen for the maximum time interval allowed right now (10 minutes)
``` swift
speechService.startListening(_ shutDownTimer: Int)
```

You can also implement some sort of cancel mechanism by calling:
```swift
speechService.stopListening()
```

As this package it's powed by Combine you can implement some action with the stop signal:
```swift
func stopListener() {
    speechService.stopSignal
        .sink { _ in
            self.someButton.isEnabled = true
            self.someButton.backgroundColor = .systemGreen
            self.someButton.setTitle("Listening Stopped", for: .normal)
        }.store(in: &cancellables)
}
```


Have fun!
