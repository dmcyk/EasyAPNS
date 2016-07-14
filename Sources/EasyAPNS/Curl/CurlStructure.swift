//
//  CurlStructure.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 13.07.2016.
//
//
import cURL

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

public enum CurlSetOption: Hashable {
    case url, port, httpHeader,
    post, postFields, timeout,
    useSsl, sslEngineDefault, sslVerifyPeer, sslCert, passPhrase, caPath,
    header, httpVersion, verbose, userAgent
    
    public var rawValue: UInt32 {
        return raw.rawValue
    }
    
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
        case postFields:
            return CURLOPT_COPYPOSTFIELDS
        case timeout:
            return CURLOPT_TIMEOUT
        case .useSsl:
            return CURLOPT_USE_SSL
        case .sslEngineDefault:
            return CURLOPT_SSLENGINE_DEFAULT
        case sslVerifyPeer:
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

public enum CurlOptionType {
    case int(Int), upInt8(UnsafePointer<Int8>), int64(Int64),
    umpCurlSlist(UnsafeMutablePointer<curl_slist>), umpVoid(UnsafeMutablePointer<Void>)
}

public struct CurlResponse {
    public static let CODE_NOT_SET = -1
    public var code: Int = CurlResponse.CODE_NOT_SET
    public var headers: [String] = []
    public var body = String()
    let parseMode: CurlParse
    
    init(parseMode: CurlParse = .trimNewLineCharacters) {
        self.parseMode = parseMode
    }
    
}

public enum CurlParse {
    case none, trimNewLineCharacters
}

public struct CurlErr: ErrorProtocol {
    var err: UInt32
    var description: String
}
