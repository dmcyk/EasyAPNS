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

/**
 Provide messages sending feedback
 */
public protocol EasyApnsDelegate: class {
    
    /**
     - parameter messageEnvelope:MessageEnvelope called after every send attempt - check `MesssageEnvelope.Status`
     */
    func sendingFeedback(_ messageEnvelope: MessageEnvelope)
    
    /**
     - returns:Bool called when sending error occurred and retry limit hasn't been exceeded - return false to cancel sending
     */
    func shouldRetry(_ messageEnvelope: MessageEnvelope) -> Bool
}

public extension EasyApnsDelegate {
    
    /**
     by default attempt to send message again
     */
    func shouldRetry(_ messageEnvelope: MessageEnvelope) -> Bool {
        return true
    }
}

/**
 Class responsible for handling connection to the APNS server and handling messages sending
 */
public final class EasyApns: SecureHttp2Con {
    
   
    /**
     EasyAPNS possible errors
     */
    public enum Error: Swift.Error {
        /**
         * header's curl slist error
         */
        case headerSlist
    }
    
    /**
     Choose between APNS environments - development and production
     */
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

    private let logger: Logger

    /**
     provide information to standard output about occuring actions
     - parameter val: verbose debug
     - parameter verboseCurl:Bool if true, sets curl to work in verbose mode
     */
    public func logMode(loggerLevel: LoggerLevel, verboseCurl: Bool) {
        logger.level = loggerLevel
        curl.set(.verbose, value: verboseCurl)
    }

    /**
     messages retry limit in case of sending failure
     */
    public var sendRetryTimes: Int = 5
    
    
    /**
     microseconds interval to wait after message sending error
     */
    public var retryMicrosecondsInterval:useconds_t = 0
    
    
    public weak var delegate: EasyApnsDelegate?

    /**
     queue for messages to be sent
     */
    public private(set) var messagesQueue = Queue<MessageEnvelope>()

    public init(environment: Environment, certificatePath: String, certificatePassphrase: String?,
                loggerLevel: LoggerLevel = .none, timeout: Int = 20) {
        logger = Logger(loggerLevel: loggerLevel)
        super.init(certificatePath: certificatePath, certificatePassphrase: certificatePassphrase, timeout: timeout)
        url = environment.url
        didSet(url: url)
        port = environment.port
        didSet(port: port)
        userAgent = "EasyAPNS"
        didSet(userAgent: userAgent)
        curl.set(.post, value: true)
    }

    /**
     - parameter message:Message message to enqueue
     - returns:[MessageEnvelope] array of message envelopes, one for each of message's device token
     */
    @discardableResult
    public func enqueue(_ message: Message) throws -> [MessageEnvelope]  {
        try message.validateDeviceTokens()
        try message.validatePayload()
        
        var envelopes = [MessageEnvelope]()
        
        for deviceToken in message.deviceTokens {
            let envelope = MessageEnvelope(message, deviceToken: deviceToken)
            messagesQueue.enqueue(envelope)
            envelopes.append(envelope)
        }
        logger.log("Message\(message.customId != nil ? " with customId: \(message.customId!)" : ""), enqueued with \(message.deviceTokens.count) device tokens", type: .info)
        return envelopes
    }

    /**
     - parameter messageEnvelope:MessageEnvelope send given message envelope 
     - returns:CurlResponse received parsed curl's response
     */
    func send(_ messageEnvelope: MessageEnvelope) throws -> CurlResponse {
        let message = messageEnvelope.message
        try message.validate(messageEnvelope.deviceToken)

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
        curl.setSlist(.httpHeader, value: curlSlist.rawSlist)

        curl.set(.postFields, value: message.jsonString)

        defer {
            curl.set(.url, value: url)
        }
        
        return try curl.execute()

    }

    /**
     send currently enqueued messages
     */
    public func sendMessagesInQueue() {
        logger.log("Sending started with \(messagesQueue.count) messages to send\n", type: .info)
        while var messageEnvelope = messagesQueue.dequeue() {
            var response: CurlResponse? = nil
            do {
                response = try send(messageEnvelope)
                if let response = response {


                    switch response.code {
                    case 200:
                        var parsedApnsId: String? = nil

                        for header in response.headers {
                            if let apnsIdHeaderEntry = strstr(header, "apns-id") {
                                let rawApnsId = apnsIdHeaderEntry.advanced(by: 9)
                                let apnsLength = header.characters.count - apnsIdHeaderEntry.distance(to: rawApnsId)
                                let raw = UnsafeMutablePointer<CChar>.allocate(capacity: apnsLength + 1)
                                raw.initialize(from: rawApnsId, count: apnsLength)
                                raw[apnsLength] = 0
                                parsedApnsId = String(cString: rawApnsId)
                                raw.deinitialize()
                                raw.deallocate(capacity: apnsLength)
                            }
                        }
                        messageEnvelope.status = MessageEnvelope.Status.successfullySent(apnsId: parsedApnsId, rawResponse: response)
                        if let parsedApnsId = parsedApnsId {
                            logger.log("Message with id: \(parsedApnsId) successfully sent", type: .info)
                        } else {
                            logger.log("Message sent with APNS id parsing error", type: .info)
                        }
                        

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
            if messageEnvelope.status.rawValue != 0 {
                
                messageEnvelope.retriesCount += 1
                if messageEnvelope.retriesCount < sendRetryTimes {
                    messageEnvelope.status = MessageEnvelope.Status.enqueuedForResend(innerState: messageEnvelope.status)
                    
                    
                    logger.log("Error sending message with app bundle id: \(messageEnvelope.message.appBundle) to device \(messageEnvelope.deviceToken), retries left: \(sendRetryTimes - messageEnvelope.retriesCount)" , type: .error)
                    if case .enqueuedForResend(let innerState) = messageEnvelope.status, innerState != nil {
                        logger.log("Enqueued for resend with inner status: \(innerState!) \n", type: .error)
                    } else {
                        logger.log("Status: \(messageEnvelope.status)", type: .error)
                    }
                    
                    if let delegate = delegate {
                        if delegate.shouldRetry(messageEnvelope) {
                            messagesQueue.enqueue(messageEnvelope)
                        }
                    } else {
                        messagesQueue.enqueue(messageEnvelope)
                    }
                    

                } else {
                    messageEnvelope.status = MessageEnvelope.Status.sendingFailed(Message.Error.exceededSendingLimit)
                    logger.log("Message with app bundle id: \(messageEnvelope.message.appBundle) to device \(messageEnvelope.deviceToken)", type: .error)
                    logger.log("Finished with error: \(messageEnvelope.status)", type: .error)

                }
                
                usleep(retryMicrosecondsInterval)
            }
            
            
            logger.log("\n\(messagesQueue.count) \(messagesQueue.count == 1 ? "envelope" : "envelopes") left in queue\n\n", type: .info)

            delegate?.sendingFeedback(messageEnvelope)
        }
    }
}
