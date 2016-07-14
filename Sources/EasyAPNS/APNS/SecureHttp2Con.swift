//
//  File.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 04.07.2016.
//
//
import libc
import cURL

public class SecureHttp2Con {
    
    public let curl: Curl
    
    public var certificatePath: String {
        didSet {
            didSet(certificatePath: certificatePath)
        }
    }
    
    func didSet(certificatePath: String) {
        let buffer = UnsafeMutablePointer<CChar>(allocatingCapacity: Int(PATH_MAX))
        realpath(certificatePath, buffer)
        curl.set(.sslCert, value: String(cString: buffer))
        buffer.deinitialize(count: Int(PATH_MAX))
        buffer.deallocateCapacity(Int(PATH_MAX))
    }
    
    public var userAgent: String? {
        didSet {
            didSet(userAgent: userAgent)
        }
    }
    
    func didSet(userAgent: String?) {
        guard let userAgent = userAgent else { return }
        curl.set(.userAgent, value: userAgent)
    }
    
    public var certificatePassphrase: String? {
        didSet {
            didSet(certificatePassphrase: certificatePassphrase)
        }
    }
    
    func didSet(certificatePassphrase: String?) {
        guard let certificatePassphrase = certificatePassphrase else { return }
        curl.set(.passPhrase, value: certificatePassphrase)
    }
    
    public var caCertificatePath: String? {
        didSet {
            didSet(caCertificatePath: caCertificatePath)
        }
    }
    
    func didSet(caCertificatePath: String?) {
        if let caCertificatePath = caCertificatePath {
            let buffer = UnsafeMutablePointer<CChar>(allocatingCapacity: Int(PATH_MAX))

            realpath(caCertificatePath, buffer)
            curl.set(.sslVerifyPeer, value: 1)
            curl.set(.caPath, value: String(cString: buffer))
            buffer.deinitialize(count: Int(PATH_MAX))
            buffer.deallocateCapacity(Int(PATH_MAX))
        } else {
            curl.set(.sslVerifyPeer, value: 0)
        }
    }
    
    public var url: String = "" {
        didSet {
            didSet(url: url)
        }
    }
    
    func didSet(url: String) {
        curl.set(.url, value: url)
    }
    
    public var port: Int  = 0 {
        didSet {
            didSet(port: port)
        }
    }
    
    func didSet(port: Int) {
        curl.set(.port, value: port)
    }
    
    public var timeout: Int {
        didSet {
            didSet(timeout: timeout)
        }
    }
    
    func didSet(timeout: Int) {
        curl.set(.timeout, value: timeout)
    }
    
    public init(certificatePath: String, timeout: Int = 20) {
        self.curl = Curl()
        self.certificatePath = certificatePath
        self.timeout = timeout
        curl.set(.httpVersion, value: CURL_HTTP_VERSION_2_0)
        didSet(certificatePath: certificatePath)
        didSet(timeout: timeout)
        curl.set(.useSsl, value: true)
        curl.set(.sslEngineDefault, value: true)
    }
}

