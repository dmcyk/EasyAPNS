# EasyAPNS

Swift APNS client built by wrapping `libcurl`'s _easy_ interface. 

## TODO 

- [x] JWT Support 
- [x] Swift's libcurl wrapper isolation and improvements - preview available at [SwiftyCurl](https://github.com/dmcyk/SwiftyCurl)

## Dependecies
* CURL with HTTP/2 support 

On macOS HTTP/2 can be installed with Homebrew using `brew install curl --with-openssl --with-nghttp2`, then you also have to link brew's curl by adding flags `-L/usr/local/opt/curl/lib -I/usr/local/opt/curl/include` (in Xcode - project's build settings -> Linking -> Other Librarian/Linker flags)

## Example usage

```swift
import EasyAPNS
import libc
import Foundation

class FeedbackCollector: EasyApnsDelegate {
    
    func sendingFeedback(_ messageEnvelope: MessageEnvelope) {
        if case .successfullySent(let apnsId) = messageEnvelope.status {
            print(apnsId ?? "no apns id")
        } else {
            print(messageEnvelope.status)
        }
    }
}


do {
    let devToken = "...";
    let appBundle = "...";
    
    var message = try Message(deviceToken: devToken, appBundle: appBundle)
    message.alert = .message("Greetings from EasyAPNS notification :)")
    message.badge = 2
    
    // JWT 
    let easyApns = try EasyApns(environment: .development, developerTeamId: "...", keyId: "...", keyPath: "...")
    
    //    let easyApns = EasyApns(environment: .development, certificatePath: "...", rawCertificatePassphrase: "...", caAuthorityPath: "...")
    
    let collector = FeedbackCollector()
    easyApns.delegate = collector
    
    try easyApns.enqueue(message)
    try easyApns.enqueue(message)
    let unsuccessful = easyApns.sendEnqueuedMessages()
    
    print("\nUnsuccessful")
    dump(unsuccessful)
    
    
} catch {
    print(error)
}
```
