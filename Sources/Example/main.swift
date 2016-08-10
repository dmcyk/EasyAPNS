//
//  main.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 04.07.2016.
//
//

import EasyAPNS

class FeedbackCollector: EasyApnsDelegate {
    
    func sendingFeedback(_ messageEnvelope: MessageEnvelope) {
        if case MessageEnvelope.Status.successfullySent(let apnsId,let curlResponse) = messageEnvelope.status {
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




