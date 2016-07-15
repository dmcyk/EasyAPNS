# EasyAPNS

Swift APNS client built by wrapping `libcurl`'s _easy_ interface. 


## Example usage

```swift
import EasyAPNS

class FeedbackCollector: EasyApnsDelegate {
    
    func sendingFeedback(messageEnvelope: MessageEnvelope) {
        if case MessageEnvelope.Status.successfullySent(let apnsId,let curlResponse) = messageEnvelope.status {
            print(apnsId)
            print(curlResponse?.headers)
        }
    }
}

let caCertPath = "/ca/cert/path.pem"

let easyApns = EasyApns(environment: .development, certificatePath: "/my/cert/path.pem")
easyApns.caCertificatePath = caCertPath
let devToken = "my-device-token"
let appBundle = "my-app-bundle"



if var message = try? Message(deviceToken: devToken, appBundle: appBundle) {
    message.alert = .message("my first EasyAPNS notification")
    message.badge = 2
    let collector = FeedbackCollector()
    easyApns.delegate = collector
    easyApns.certificatePassphrase = "mypassphrase"
    
    try easyApns.enqueue(message: message)
    easyApns.sendMessagesInQueue()
}
```
