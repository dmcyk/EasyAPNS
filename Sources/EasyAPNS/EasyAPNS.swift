//
//  ApnsCon.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 05.07.2016.
//
//

import cURL
import libc
@_exported import JSON



public protocol EasyApnsDelegate: class {
    func sendingFeedback(messageEnvelope: MessageEnvelope)
}

public final class EasyApns: SecureHttp2Con {
    
    public enum Error: ErrorProtocol {
        case headerSlist
    }
    
    public enum Environment {
        case development, production
        
        var url: String {
            switch self {
            case .development:
                return "https://api.development.push.apple.com"
            case .production:
                return "https://api.push.apple.com"
            }
        }
        
        var port: Int {
            return 443
        }
    }
    
    public var debug = false {
        didSet {
            didSet(debug: debug)
        }
    }

    func didSet(debug: Bool) {
        curl.set(.verbose, value: debug)
    }

    public var sendRetryTimes: Int = 5
    public weak var delegate: EasyApnsDelegate?

    public private(set) var messagesQueue = Queue<MessageEnvelope>()

    public init(environment: Environment, certificatePath: String,
                timeout: Int = 20) {
        super.init(certificatePath: certificatePath, timeout: timeout)
        url = environment.url
        didSet(url: url)
        port = environment.port
        didSet(port: port)
        userAgent = "EasyAPNS"
        didSet(userAgent: userAgent)
        curl.set(.post, value: true)
    }


    @discardableResult
    public func enqueue(message: Message) throws -> [MessageEnvelope]  {
        try message.validateDeviceTokens()
        try message.validatePayload()
        
        var envelopes = [MessageEnvelope]()
        for deviceToken in message.deviceTokens {
            let envelope = MessageEnvelope(message, deviceToken: deviceToken)
            messagesQueue.enqueue(envelope)
            envelopes.append(envelope)
        }

        return envelopes
    }

    func send(messageEnvelope: MessageEnvelope) throws -> CurlResponse {
        let message = messageEnvelope.message
        try message.validate(deviceToken: messageEnvelope.deviceToken)

        let endPoint = "\(url)/3/device/\(messageEnvelope.deviceToken)"
        curl.set(.url, value: endPoint)
        var headers = [
            "apns-topic: \(message.appBundle)",
            "Content-Type: application/json"
        ]

        if let customId = message.customId {
            headers.append("apns-id: \(customId)")
        }
        guard let curlSlist = CurlSlist(fromArray: headers) else {
            throw EasyApns.Error.headerSlist
        }
        curl.set(.httpHeader, value: curlSlist.rawSlist)

        curl.set(.postFields, value: message.jsonString)

        defer {
            curl.set(.url, value: url)
        }
        
        return try curl.execute()

    }

    public func sendMessagesInQueue() {
        while var messageEnvelope = messagesQueue.dequeue() {
            var response: CurlResponse? = nil
            do {
                response = try send(messageEnvelope: messageEnvelope)
                if let response = response {


                    switch response.code {
                    case 200:
                        var parsedApnsId: String? = nil

                        for header in response.headers {
                            if let apnsIdHeaderEntry = strstr(header, "apns-id") {
                                let rawApnsId = apnsIdHeaderEntry.advanced(by: 9)
                                let apnsLength = header.characters.count - apnsIdHeaderEntry.distance(to: rawApnsId)
                                let raw = UnsafeMutablePointer<CChar>(allocatingCapacity: apnsLength + 1)
                                raw.initializeFrom(rawApnsId, count: apnsLength)
                                raw[apnsLength] = 0
                                parsedApnsId = String(cString: rawApnsId)
                                raw.deinitialize()
                                raw.deallocateCapacity(apnsLength)
                            }                        }
                        messageEnvelope.status = MessageEnvelope.Status.successfullySent(apnsId: parsedApnsId, rawResponse: response)

                    case 400:
                       
                        do {
                            let parsedBody = try JSONParser().parse(data: response.body.data)
                            if let reason = parsedBody["reason"]?.stringValue {
                                messageEnvelope.status = MessageEnvelope.Status.badRequest(.reason(reason))
                            } else {
                                messageEnvelope.status = MessageEnvelope.Status.badRequest(.raw(json: parsedBody))
                            }
                        } catch let e {
                            messageEnvelope.status = MessageEnvelope.Status.responseParsingError(jsonParserErr: e, rawResponse: response)
                        }
                    default:
                        messageEnvelope.status = MessageEnvelope.Status(rawValue: response.code)
                    }
                }

            } catch let e {
                messageEnvelope.status = MessageEnvelope.Status.sendingFailed(e)
            }
            if messageEnvelope.status != MessageEnvelope.Status.successfullySent(apnsId: nil, rawResponse: response) {
                messageEnvelope.retriesCount += 1
                if messageEnvelope.retriesCount < sendRetryTimes {
                    messagesQueue.enqueue(messageEnvelope)
                
                    messageEnvelope.status = MessageEnvelope.Status.enqueuedForResend(innerState: messageEnvelope.status)
                } else {
                    messageEnvelope.status = MessageEnvelope.Status.sendingFailed(MessageError.exceededSendingLimit)
                }
            }

            delegate?.sendingFeedback(messageEnvelope: messageEnvelope)
        }
    }
}
