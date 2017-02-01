//
//  MessageEnvelope.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 04.07.2016.
//
//

import JSON
import SwiftyCurl
import Foundation

fileprivate var MessageReason: [String: String] = [
    "BadCollapseId": "The collapse identifier exceeds the maximum allowed size"
]
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
        case incorrectRequest(BadRequestResponse)
        case incorrectCertificate(BadRequestResponse)
        case incorrectPath
        case incorrectRequestMethod
        case deviceTokenNoLongerActive(lastActiveTimestamp: String?)
        case payloadTooLarge
        case tooManyRequestsForGivenToken(BadRequestResponse)
        case serverInternalError
        case serverShutdown(BadRequestResponse)
        case unknown(rawResponse: cURLResponse, parsed: BadRequestResponse)
        
        ///
        ///
        /// - raw: raw response data - used in case there's an error extracting JSON
        /// - json: json response data - used when reason couldn't have been extracted
        /// - reason: APNS error reason detailed description https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html#//apple_ref/doc/uid/TP40008194-CH11-SW1
        public enum BadRequestResponse {
            case raw(Data?), json(JSON), reason(String)
        }
        
        public var inner: Status {
            switch self {
            case .enqueuedForResend(let inner):
                return inner
            default:
                return self
            }
        }
        
        public var rawValue: Int {

            switch self {
            case .notSend:
                return -1
            case .successfullySent:
                return 0
            case .enqueuedForResend(_):
                return 1
            case .sendingFailed:
                return 2
            case .exceededSendingLimit:
                return 3
            case .resendingCanceled:
                return 4 
            case .incorrectRequest:
                return 400
            case .incorrectCertificate:
                return 403
            case .incorrectPath:
                return 404
            case .incorrectRequestMethod:
                return 405
            case .deviceTokenNoLongerActive(_):
                return 410
            case .payloadTooLarge:
                return 413
            case .tooManyRequestsForGivenToken:
                return 429
            case .serverInternalError:
                return 500
            case .serverShutdown:
                return 503
            case .unknown(_):
                return -2
            case .missingResponse:
                return -3 
            }
        }
        
        
        init(response: cURLResponse) {
            var jsonBody: JSON?
            var reason: String?
            var timestamp: String?
            var badRequestRes: BadRequestResponse = .raw(nil)
            if let body = response.rawBody {
                jsonBody = try? JSON.Parser.parse(body)
                if let json = jsonBody {
                    reason = json["reason"].string
                    if let reason = reason {
                        badRequestRes = .reason(reason)
                    } else {
                        badRequestRes = .json(json)
                    }
                    timestamp = json["timestamp"].string
                } else {
                    badRequestRes = .raw(body)
                }
            }
            
            
            switch response.code {
            case 200:
                var id: String?
                for header in response.headers {
                    if let apnsIdHeaderEntry = strstr(header, "apns-id") {
                        let rawApnsId = apnsIdHeaderEntry.advanced(by: 9)
                        let apnsLength = header.characters.count - apnsIdHeaderEntry.distance(to: rawApnsId)
                        let raw = UnsafeMutablePointer<CChar>.allocate(capacity: apnsLength + 1)
                        raw.initialize(from: rawApnsId, count: apnsLength)
                        raw[apnsLength] = 0
                        id = String(cString: rawApnsId)
                        raw.deinitialize()
                        raw.deallocate(capacity: apnsLength)
                    }
                }
                self = MessageEnvelope.Status.successfullySent(apnsId: id)
            case 400:
                self = .incorrectRequest(badRequestRes)
            case 403:
                self = .incorrectCertificate(badRequestRes)
            case 404:
                self = .incorrectPath
            case 405:
                self = .incorrectRequestMethod
            case 410:
                self = .deviceTokenNoLongerActive(lastActiveTimestamp: timestamp)
            case 413:
                self = .payloadTooLarge
            case 429:
                self = .tooManyRequestsForGivenToken(badRequestRes)
            case 500:
                self = .serverInternalError
            case 503:
                self = .serverShutdown(badRequestRes)
            default:
                self = .unknown(rawResponse: response, parsed: badRequestRes)
            }
        }
        
    }
    
    
    public let message: Message
    
    
    public let deviceToken: String
    
    
    public internal(set) var status: Status
    
    
    public internal(set) var retriesCount: Int = 0
    
    
    public init(_ message: Message, deviceToken: String) {
        self.deviceToken = deviceToken
        self.message = message
        self.status = .notSend
        
    }
    
}

