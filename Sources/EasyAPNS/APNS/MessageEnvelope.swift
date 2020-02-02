//
//  MessageEnvelope.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 04.07.2016.
//
//

import SwiftyCurl
import Foundation

fileprivate var MessageReason: [String: String] = [
  "BadCollapseId": "The collapse identifier exceeds the maximum allowed size"
]

public struct MessageFailureResponse: Codable {

  /// APNS error reason detailed description https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html#//apple_ref/doc/uid/TP40008194-CH11-SW1
  public var reason: String
  public var timestamp: Int?
}

/**
 * Message wrapper in `EasyAPNS` per device token, contains information about sending status of the wrapped message
 */
public struct MessageEnvelope {
  /**
     Sending status representation of `MessageEnvelope`
     */
  public enum Status {
    case notSend
    case missingResponse
    indirect case enqueuedForResend(inner: Status)
    indirect case sendingFailed(last: Status, error: Any)
    indirect case exceededSendingLimit(last: Status?)
    indirect case resendingCanceled(last: Status)
    case successfullySent(apnsId: String?)
    case incorrectRequest(MessageFailureResponse?)
    case incorrectCertificate(MessageFailureResponse?)
    case incorrectPath
    case incorrectRequestMethod
    case deviceTokenNoLongerActive(MessageFailureResponse?)
    case payloadTooLarge
    case tooManyRequestsForGivenToken(MessageFailureResponse?)
    case serverInternalError
    case serverShutdown(MessageFailureResponse?)
    case unknown(rawResponse: cURLResponse, parsed: MessageFailureResponse?)
    public var inner: Status {
      switch self {
      case .enqueuedForResend(let inner): return inner
      default: return self
      }
    }
    public var rawValue: Int {
      switch self {
      case .notSend: return -1
      case .successfullySent: return 0
      case .enqueuedForResend(_): return 1
      case .sendingFailed: return 2
      case .exceededSendingLimit: return 3
      case .resendingCanceled: return 4
      case .incorrectRequest: return 400
      case .incorrectCertificate: return 403
      case .incorrectPath: return 404
      case .incorrectRequestMethod: return 405
      case .deviceTokenNoLongerActive(_): return 410
      case .payloadTooLarge: return 413
      case .tooManyRequestsForGivenToken: return 429
      case .serverInternalError: return 500
      case .serverShutdown: return 503
      case .unknown(_): return -2
      case .missingResponse: return -3
      }
    }

    init(response: cURLResponse) {
      var failureResponse: MessageFailureResponse? = nil
      if let body = response.rawBody {
        if let messageResponse = try? JSONDecoder().decode(
          MessageFailureResponse.self,
          from: body
        ) { failureResponse = messageResponse }
      }
      switch response.code {
      case 200:
        var id: String?
        for header in response.headers {
          if let apnsIdHeaderEntry = strstr(header, "apns-id") {
            let rawApnsId = apnsIdHeaderEntry.advanced(by: 9)
            let apnsLength = header.count
              - apnsIdHeaderEntry.distance(to: rawApnsId)
            let raw = UnsafeMutablePointer<CChar>.allocate(
              capacity: apnsLength + 1
            )
            raw.initialize(from: rawApnsId, count: apnsLength)
            raw[apnsLength] = 0
            id = String(cString: rawApnsId)
            raw.deinitialize(count: apnsLength)
            raw.deallocate()
          }
        }
        self = MessageEnvelope.Status.successfullySent(apnsId: id)
      case 400: self = .incorrectRequest(failureResponse)
      case 403: self = .incorrectCertificate(failureResponse)
      case 404: self = .incorrectPath
      case 405: self = .incorrectRequestMethod
      case 410: self = .deviceTokenNoLongerActive(failureResponse)
      case 413: self = .payloadTooLarge
      case 429: self = .tooManyRequestsForGivenToken(failureResponse)
      case 500: self = .serverInternalError
      case 503: self = .serverShutdown(failureResponse)
      default: self = .unknown(rawResponse: response, parsed: failureResponse)
      }
    }
  }
  public let message: Message
  public let deviceToken: String
  public internal(set) var status: Status

  public internal(set) var retriesCount: Int = 0

  let messageData: Data

  init(_ message: Message, deviceToken: String, messageData: Data) {
    self.deviceToken = deviceToken
    self.messageData = messageData
    self.message = message
    self.status = .notSend
  }
}
