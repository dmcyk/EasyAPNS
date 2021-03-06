//
//  ApnsCon.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 05.07.2016.
//
//

import SwiftyCurl
import libc
import CCurl
import Foundation

/**
 Provide messages sending feedback
 */
public protocol EasyApnsDelegate: class {
  /**
     - parameter messageEnvelope:MessageEnvelope called after every successfull sending attempt and when retry limit has been exceeded, for feedback when retries limit is yet to be reached check `shouldRetry`
     */
  func sendingFeedback(_ messageEnvelope: MessageEnvelope)
  /**
     - returns:Bool called when sending error occurred and retry limit has not been exceeded - return false to cancel sending. By default attempt to send message again
     */
  func shouldRetry(_ messageEnvelope: MessageEnvelope) -> Bool
}

public extension EasyApnsDelegate {

  func shouldRetry(_ messageEnvelope: MessageEnvelope) -> Bool { return true }
}

///  Handling connection with APNS server and messages sending
public final class EasyApns: cURLConnection {

  public enum Error: Swift.Error { case `internal` }
  public enum AuthenticationMethod {
    case certificate(
      path: String,
      keyPath: String?,
      rawPassphrase: String?,
      caAuthority: String?
    )
    case jwt(JWTData)
  }
  public enum Environment {
    case development, production
    var url: String {
      switch self {
      case .development: return "https://api.development.push.apple.com"
      case .production: return "https://api.push.apple.com"
      }
    }
    var port: Int { return 443 }
  }
  /// JSON Web Token authentication configuration 
  public struct JWTData {

    struct Claims: Codable {

      let iss: String
      let iat: Int
    }

    struct Header: Codable {

      let alg: String
      let kid: String
    }

    private let jwtHeader: String
    private let signer: ES256
    private(set) var developerTeamId: String
    private let encoding = Base64URLEncoding()
    private let keyPathToken: (privateKey: Data, publicKey: Data?)
    fileprivate var needsTokenRefreshing = true
    private var previousToken: String? = nil
    public init(developerTeamId: String, keyId: String, keyPath: String) throws
    {
      self.keyPathToken = try keyPath.tokenString()
      let privateKey = keyPathToken.privateKey
      signer = ES256(key: privateKey)
      self.developerTeamId = developerTeamId
      let rawHeader = try JSONEncoder().encode(Header(alg: "ES256", kid: keyId))
      self.jwtHeader = try encoding.encode(rawHeader)
    }
    private func generateToken() throws -> String {
      let timestamp = Int(Date().timeIntervalSince1970)

      let claims = Claims(iss: developerTeamId, iat: timestamp)
      let serialized = try JSONEncoder().encode(claims)
      let claimsEncoded = try encoding.encode(serialized)
      let encoded: [String] = [jwtHeader, claimsEncoded]
      let dataString = encoded.joined(separator: ".")
      let raw = try signer.sign(message: dataString.convertToData())
      let sign = try encoding.encode(raw)
      return "\(dataString).\(sign)"
    }
    fileprivate mutating func header() throws -> (String, String) {
      let token: String
      if let previousToken = previousToken, !needsTokenRefreshing {
        token = previousToken
      } else {
        token = try generateToken()
        previousToken = token
        needsTokenRefreshing = false
      }
      return ("Authorization", "bearer \(token)")
    }
  }
  private var authMethod: AuthenticationMethod
  /**
     messages retry limit in case of sending failure
     */
  public var sendRetryTimes: Int = 1
  /**
     microseconds interval to wait after message sending error
     */
  public var retryMicrosecondsInterval: useconds_t = 0

  public weak var delegate: EasyApnsDelegate?
  public private(set) var messagesQueue = Queue<MessageEnvelope>()
  public init(
    environment: Environment,
    authenticationMethod: AuthenticationMethod,
    loggerLevel: LoggerLevel = .allEnabled,
    timeout: Int = 20
  ) {
    Logger.shared.level = loggerLevel
    authMethod = authenticationMethod
    switch authenticationMethod {
    case .certificate(let path, let keyPath, let passphrase, let caAuthority):
      super.init(
        useSSL: true,
        url: environment.url,
        certificatePath: path,
        keyPath: keyPath,
        certificatePassphrase: passphrase,
        caPath: caAuthority,
        timeout: timeout
      )
    case .jwt(_):
      super.init(useSSL: true, url: environment.url, timeout: timeout)
    }

    userAgent = "EasyAPNS"
    didSet(userAgent: userAgent)
    curl.set(.httpVersion, value: CURL_HTTP_VERSION_2_0)

  }
  public convenience init(
    environment: Environment,
    certificatePath: String,
    certificateKeyPath: String,
    caAuthorityPath: String? = nil,
    loggerLevel: LoggerLevel = .allEnabled
  ) {
    let auth = AuthenticationMethod.certificate(
      path: certificatePath,
      keyPath: certificateKeyPath,
      rawPassphrase: nil,
      caAuthority: caAuthorityPath
    )
    self.init(
      environment: environment,
      authenticationMethod: auth,
      loggerLevel: loggerLevel
    )
  }
  public convenience init(
    environment: Environment,
    certificatePath: String,
    rawCertificatePassphrase: String,
    caAuthorityPath: String? = nil,
    loggerLevel: LoggerLevel = .allEnabled
  ) {
    let auth = AuthenticationMethod.certificate(
      path: certificatePath,
      keyPath: nil,
      rawPassphrase: rawCertificatePassphrase,
      caAuthority: caAuthorityPath
    )
    self.init(
      environment: environment,
      authenticationMethod: auth,
      loggerLevel: loggerLevel
    )
  }
  public convenience init(
    environment: Environment,
    developerTeamId: String,
    keyId: String,
    keyPath: String,
    loggerLevel: LoggerLevel = .allEnabled
  ) throws {
    let auth = try AuthenticationMethod.jwt(
      JWTData(developerTeamId: developerTeamId, keyId: keyId, keyPath: keyPath)
    )
    self.init(
      environment: environment,
      authenticationMethod: auth,
      loggerLevel: loggerLevel
    )
  }

  /**
     Provide information to standard output about occuring actions
     - parameter val: verbose debug
     */
  public func setLoggerLevel(_ loggerLevel: LoggerLevel) {
    Logger.shared.level = loggerLevel
  }
  /**
     - parameter verboseCurl:Bool if true, sets curl to work in verbose mode
     */
  public func verboseCurl(_ verboseCurl: Bool) {
    curl.set(.verbose, value: verboseCurl)
  }
  /**
     - parameter message:Message message to enqueue
     */
  public func enqueue(_ message: inout Message) throws {
    let messageData = try message.validate()
    for deviceToken in message.deviceTokens {
      var singleDeviceTokenMessage = message
      singleDeviceTokenMessage.deviceTokens = [deviceToken]
      let envelope = MessageEnvelope(
        singleDeviceTokenMessage,
        deviceToken: deviceToken,
        messageData: messageData
      )
      messagesQueue.enqueue(envelope)
    }

    logVerbose(
      "Message\(message.customId != nil ? " with customId: \(message.customId!)," : "") enqueued with \(message.deviceTokens.count) device tokens"
    )
  }

  /**
     - parameter messageEnvelope:MessageEnvelope send given message envelope 
     - returns:CurlResponse received parsed curl's response
     */
  func send(_ messageEnvelope: MessageEnvelope) throws -> cURLResponse? {
    let message = messageEnvelope.message
    try message.validate(deviceToken: messageEnvelope.deviceToken)
    let apnsUrl = url

    guard
      let endUrl = URL(
        string: url.appending("/3/device/\(messageEnvelope.deviceToken)")
      )
    else { throw Error.internal }

    var headers = ["apns-topic": "\(message.appBundle)"]
    if case .jwt(var data) = authMethod {
      let authHeader = try data.header()
      headers[authHeader.0] = authHeader.1
      authMethod = .jwt(data)
    }
    if let customId = message.customId { headers["apns-id"] = "\(customId)" }
    if let collapseId = message.collapseId {
      headers["apns-collapse-id"] = collapseId
    }
    headers["apns-priority"] = "\(message.priority.rawValue)"
    switch message.expiration {
    case .default: break
    case .at(let timestamp):
      headers["apns-expiration"] = "\(timestamp.timeIntervalSince1970)"
    case .immediate: headers["apns-expiration"] = "0"
    }

    var req = cURLRequest(
      url: endUrl,
      method: .post,
      headers: headers,
      body: messageEnvelope.messageData
    )
    req.contentType = .json

    let res = try request(req)
    url = apnsUrl

    return res
  }
  private func sendAndSetStatus(
    forMessageEnvelope messageEnvelope: inout MessageEnvelope
  ) -> Bool {
    var response: cURLResponse? = nil
    do {
      response = try send(messageEnvelope)
      if let response = response {
        let status = MessageEnvelope.Status(response: response)
        if case .successfullySent(let parsedApnsId) = status {
          if let parsedApnsId = parsedApnsId {
            logVerbose("Message with id: \(parsedApnsId) successfully sent")
          } else {
            logVerbose(
              "Message successfully sent, but APNS id parsing error occurred"
            )
          }
        } else if case .incorrectCertificate(let badRequest) = status {
          // check if needs JWT token refresh
          if case .jwt(var data) = authMethod {
            if let reason = badRequest?.reason {
              if reason == "ExpiredProviderToken" {
                logVerbose("Provider token expired, requesting refresh")
                data.needsTokenRefreshing = true
                authMethod = .jwt(data)
                messagesQueue.enqueue(messageEnvelope)
                return true
              }
            }
          }
        }
        messageEnvelope.status = status
      } else { messageEnvelope.status = .missingResponse }
    } catch let e {
      messageEnvelope.status = MessageEnvelope.Status.sendingFailed(
        last: messageEnvelope.status.inner,
        error: e
      )
    }
    return false
  }

  /**
     Send enqueued messages
     - returns:[MessageEnvelope] Envelopes with Messages which have not been successfully sent
     */
  public func sendEnqueuedMessages() -> [MessageEnvelope] {
    logVerbose("Sending started with \(messagesQueue.count) messages to send\n")
    var unsuccessfull: [MessageEnvelope] = []
    while var messageEnvelope = messagesQueue.dequeue() {
      if sendAndSetStatus(forMessageEnvelope: &messageEnvelope) {
        // requested revoking JWT token
        continue
      }
      if messageEnvelope.status.rawValue != 0 {
        messageEnvelope.retriesCount += 1
        if messageEnvelope.retriesCount < sendRetryTimes {
          var retryFlag = true
          if let delegate = delegate {
            retryFlag = delegate.shouldRetry(messageEnvelope)
          }
          let messageInfo =
            "Error sending message with app bundle id: \(messageEnvelope.message.appBundle) to device \(messageEnvelope.deviceToken),"
          if retryFlag {
            logWarning(
              "\(messageInfo) retries left: \(sendRetryTimes - messageEnvelope.retriesCount)"
            )
            let innerStatus = messageEnvelope.status
            messageEnvelope.status = MessageEnvelope.Status.enqueuedForResend(
              inner: messageEnvelope.status
            )
            logWarning(
              "Enqueued for resend with inner status: \(innerStatus) \n"
            )
            messagesQueue.enqueue(messageEnvelope)

          } else {
            logDebug("\(messageInfo) resending cancelled")
            messageEnvelope.retriesCount = sendRetryTimes
            messageEnvelope.status = MessageEnvelope.Status.resendingCanceled(
              last: messageEnvelope.status.inner
            )
            unsuccessfull.append(messageEnvelope)
          }
        } else {
          // retries limit reached
          messageEnvelope.status = MessageEnvelope.Status.exceededSendingLimit(
            last: messageEnvelope.status.inner
          )
          logError(
            "Message with app bundle id: \(messageEnvelope.message.appBundle) to device \(messageEnvelope.deviceToken)"
          )
          logError("\tFinished sending with error: \(messageEnvelope.status)")
          unsuccessfull.append(messageEnvelope)

          delegate?.sendingFeedback(messageEnvelope)

        }
        usleep(retryMicrosecondsInterval)
      } else { delegate?.sendingFeedback(messageEnvelope) }
      logVerbose(
        "\(messagesQueue.count) \(messagesQueue.count == 1 ? "envelope" : "envelopes") left in queue\n"
      )

    }
    return unsuccessfull
  }
}
