# EasyAPNS

Swift APNS client built by wrapping `libcurl`'s _easy_ interface. 

## Dependecies
* CURL with HTTP/2 support 

On macOS HTTP/2 can be installed with Homebrew using `brew install curl --with-openssl --with-nghttp2`, then you also have to link brew's curl by adding flags `-L/usr/local/opt/curl/lib -I/usr/local/opt/curl/include` (in Xcode - project's build settings -> Linking -> Other Librarian/Linker flags)

* LibreSSL/OpenSSL

Starting from v1.0.0 `EasyAPNS` no longer includes LibreSSL, thus it must be explicitly linked. 


## Example setup

### Developer account 
In order to be able to use APNS you need to properly configure you developer account and capabilities of your applications. 
You can find out more at [Apple website](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/APNSOverview.html#//apple_ref/doc/uid/TP40008194-CH8-SW1),especially in `Provider-to-APNs Connection Trust` section - which explains what is necessary in order to be able to establish APNS connection. 

### Generate Xcode project for debugging 
```swift package -Xswiftc -I/usr/local/opt/libressl/include/ -Xlinker -L/usr/local/opt/libressl/lib -Xlinker -L/usr/local/opt/curl/lib -Xswiftc -I/usr/local/opt/curl/include -Xswiftc "-DDEBUG" generate-xcodeproj```

Note: this command assumes you have installed `LibreSSL` and `CURL` with Homebrew, if you're using OpenSSL instead or another package manager make sure to properly adjust the linking flags. 


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

- general cleanup
- 
