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

class FeedbackCollector: EasyApnsDelegate {
    
    func sendingFeedback(_ messageEnvelope: MessageEnvelope) {
        if case .successfullySent(let apnsId,let curlResponse) = messageEnvelope.status {
            print(apnsId)
            print(curlResponse?.headers)
        }
    }
}

let caCertPath = "/ca/cert/path.pem"

let easyApns = EasyApns(environment: .development, certificatePath: "/my/cert/path.pem",
                        certificatePassphrase: "myPassphrase", loggerLevel: [.info, .error])

easyApns.caCertificatePath = caCertPath

let devToken = "dev_token"
let appBundle = "my_app_bundle"



if var message = try? Message(deviceToken: devToken, appBundle: appBundle) {
    message.alert = .message("Greetings from Swifty EasyAPNS notification :)")
    message.badge = 2
    let collector = FeedbackCollector()
    easyApns.delegate = collector
    
    try easyApns.enqueue(message)
    easyApns.sendMessagesInQueue()
}
```
