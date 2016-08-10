//
//  CurlStructure.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 13.07.2016.
//
//
import cURL

/**
 * Swift wrapper for curl_getinfo options
 */
public enum CurlGetOption {
    case httpResponseCode, headerSize
    
    public var rawValue: UInt32 {
        return raw.rawValue
    }
    
    public var raw: CURLINFO {
        switch self {
        case .httpResponseCode:
            return CURLINFO_RESPONSE_CODE
        case .headerSize:
            return CURLINFO_HEADER_SIZE
        }
    }
}

/**
 * Swift wrapper for curl_setopt options
 */
public enum CurlSetOption: Hashable {
    case url, port, httpHeader,
    post, postFields, timeout,
    useSsl, sslEngineDefault, sslVerifyPeer, sslCert, passPhrase, caPath,
    header, httpVersion, verbose, userAgent
    
    /**
     * curl's raw number option
     */
    public var rawValue: UInt32 {
        return raw.rawValue
    }
    
    
    /**
     * raw CURLOption value
     */
    public var raw: CURLoption {
        switch self {
        case .url:
            return CURLOPT_URL
        case .port:
            return CURLOPT_PORT
        case .httpHeader:
            return CURLOPT_HTTPHEADER
        case .post:
            return CURLOPT_POST
        case .postFields:
            return CURLOPT_COPYPOSTFIELDS
        case .timeout:
            return CURLOPT_TIMEOUT
        case .useSsl:
            return CURLOPT_USE_SSL
        case .sslEngineDefault:
            return CURLOPT_SSLENGINE_DEFAULT
        case .sslVerifyPeer:
            return CURLOPT_SSL_VERIFYPEER
        case .sslCert:
            return CURLOPT_SSLCERT
        case .caPath:
            return CURLOPT_CAPATH
        case .passPhrase:
            return CURLOPT_KEYPASSWD
        case .header:
            return CURLOPT_HEADER
        case .httpVersion:
            return CURLOPT_HTTP_VERSION
        case .verbose:
            return CURLOPT_VERBOSE
        case .userAgent:
            return CURLOPT_USERAGENT
        }
        
    }
    
    public var hashValue: Int {
        return Int(rawValue)
    }
    
}

/**
 * curl types enum, to allow setting many options at once
 */
public enum CurlOptionType {
    case int(Int), upInt8(UnsafePointer<Int8>), int64(Int64),
    umpCurlSlist(UnsafeMutablePointer<curl_slist>), umpVoid(UnsafeMutablePointer<Void>)
}


/**
 * structural representation of raw curl response
 */
public struct CurlResponse {
    
    /**
     * -1 stands for code not yet set
     */
    public var code: Int = -1
    
    /**
     * parsed array of headers
     */
    public var headers: [String] = []
    
    /**
     * response body
     */
    public var body = String()
    let parseMode: CurlParse
    
    init(parseMode: CurlParse = .trimNewLineCharacters) {
        self.parseMode = parseMode
    }
    
}

/**
 * curl response parsing mode
 */
public enum CurlParse {
    
    /// no parsing, keep data received from curl
    case none
    
    /// trim new HTTP's new line characters
    case trimNewLineCharacters
}

/**
 * representation of curl's error
 */
public struct CurlErr: Error {
    
    /**
     * curl's error code
     */
    public let err: UInt32
    
    /**
     *  error description using curl_easy_strerror
     */
    public let description: String
    
    init(err: UInt32, description: String) {
        self.err = err
        self.description = description
    }
    
    
    init(err: UInt32, curlCode: CURLcode) {
        self.err = err
        self.description = String(cString: curl_easy_strerror(curlCode))
    }
}
