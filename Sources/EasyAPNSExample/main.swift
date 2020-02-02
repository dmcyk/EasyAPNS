//
//  main.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 04.07.2016.
//
//

import EasyAPNS
import libc
import Foundation

class FeedbackCollector: EasyApnsDelegate {

  func sendingFeedback(_ messageEnvelope: MessageEnvelope) {
    print("FeedbackCollector: ", terminator: "")
    if case .successfullySent(let apnsId) = messageEnvelope.status {
      print("Sent: \(apnsId ?? "no apns id")")
    } else { print(messageEnvelope.status) }
  }
}

do {
  let devToken = ".."
  let appBundle = "..";

  var message = try Message(deviceToken: devToken, appBundle: appBundle)
  message.alert = .message("Greetings from EasyAPNS notification :)")
  message.badge = 2

  // JWT 
  let easyApns = try EasyApns(
    environment: .development,
    developerTeamId: "..",
    keyId: "..",
    keyPath: ".."
  )

  // certificate
  //    let easyApns = EasyApns(environment: .development, certificatePath: "...", rawCertificatePassphrase: "...", caAuthorityPath: "...")

  let collector = FeedbackCollector()
  easyApns.delegate = collector
  try easyApns.enqueue(&message)
  try easyApns.enqueue(&message)

  let unsuccessful = easyApns.sendEnqueuedMessages()
  print("Unsuccessful:")
  dump(unsuccessful)
} catch { print(error) }
