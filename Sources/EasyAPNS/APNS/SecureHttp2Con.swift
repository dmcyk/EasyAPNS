//
//  File.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 04.07.2016.
//
//
import libc
import cURL

/**
 * Abstract class for curl HTTP/2 certificate based connection 
 */
public class SecureHttp2Con {
    
    /**
     * connection's curl reference
     */
    public let curl: Curl
    
    /**
     * absolute path to certificate which is to be used during connection
     */
    public var certificatePath: String {
        didSet {
            didSet(certificatePath: certificatePath)
        }
    }
    
    func didSet(certificatePath: String) {
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(PATH_MAX))
        realpath(certificatePath, buffer)
        curl.set(.sslCert, value: String(cString: buffer))
        buffer.deinitialize(count: Int(PATH_MAX))
        buffer.deallocate(capacity: Int(PATH_MAX))
    }
    
    /**
     * custom user-agent
     */
    public var userAgent: String? {
        didSet {
            didSet(userAgent: userAgent)
        }
    }
    
    func didSet(userAgent: String?) {
        guard let userAgent = userAgent else { return }
        curl.set(.userAgent, value: userAgent)
    }
    
    /**
     * optional certificate's passphrase
     */
    public var certificatePassphrase: String? {
        didSet {
            didSet(certificatePassphrase: certificatePassphrase)
        }
    }
    
    func didSet(certificatePassphrase: String?) {
        guard let certificatePassphrase = certificatePassphrase else { return }
        curl.set(.passPhrase, value: certificatePassphrase)
    }
    
    /**
     * set path to certificate authority file
     */
    public var caCertificatePath: String? {
        didSet {
            didSet(caCertificatePath: caCertificatePath)
        }
    }
    
    func didSet(caCertificatePath: String?) {
        if let caCertificatePath = caCertificatePath {
            let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(PATH_MAX))

            realpath(caCertificatePath, buffer)
            curl.set(.sslVerifyPeer, value: 1)
            curl.set(.caPath, value: String(cString: buffer))
            buffer.deinitialize(count: Int(PATH_MAX))
            buffer.deallocate(capacity: Int(PATH_MAX))
        } else {
            curl.set(.sslVerifyPeer, value: 0)
        }
    }
    
    /**
     * request url
     */
    public var url: String = "" {
        didSet {
            didSet(url: url)
        }
    }
    
    func didSet(url: String) {
        curl.set(.url, value: url)
    }
    
    /**
     * request port
     */
    public var port: Int  = 0 {
        didSet {
            didSet(port: port)
        }
    }
    
    func didSet(port: Int) {
        curl.set(.port, value: port)
    }
    
    /**
     * curl's maximum timeout
     */
    public var timeout: Int {
        didSet {
            didSet(timeout: timeout)
        }
    }
    
    func didSet(timeout: Int) {
        curl.set(.timeout, value: timeout)
    }
    
    /**
     - parameter certificatePath:String absolute path to certificate used to instantiate secure connection
     */
    public init(certificatePath: String, certificatePassphrase: String?, timeout: Int = 20) {
        self.curl = Curl()
        self.certificatePath = certificatePath
        self.timeout = timeout
        self.certificatePassphrase = certificatePassphrase
        didSet(certificatePassphrase: certificatePassphrase)
        curl.set(.httpVersion, value: CURL_HTTP_VERSION_2_0)
        didSet(certificatePath: certificatePath)
        didSet(timeout: timeout)
        curl.set(.useSsl, value: true)
        curl.set(.sslEngineDefault, value: true)
    }
}

