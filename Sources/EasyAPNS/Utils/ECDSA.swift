// https://github.com/siemensikkema/vapor-jwt
//
//
//
//MIT License
//
//Copyright (c) 2017 Siemen Sikkema
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.
//
//


import CLibreSSL
import Core
import Foundation
import Hash

public enum JWTError: Error {
    case decoding, encoding
    case signing, createKey, createPublicKey
}

struct Base64URLEncoding: Encoding {
    private let base64URLTranscoder: Base64URLTranscoding
    
    public init() {
        self.init(base64URLTranscoder: Base64URLTranscoder())
    }
    
    init(base64URLTranscoder: Base64URLTranscoding) {
        self.base64URLTranscoder = base64URLTranscoder
    }
    
    public func encode(_ bytes: Bytes) throws -> String {
        guard let base64URL = base64URLTranscoder.base64URLEncode( bytes.base64String) else {
            throw JWTError.encoding
        }
        return base64URL
    }
    
    public func decode(_ base64URLEncoded: String) throws -> Bytes {
        guard
            let base64Encoded = base64URLTranscoder.base64Encode(base64URLEncoded),
            let data = Data(base64Encoded: base64Encoded) else {
                throw JWTError.decoding
        }
        return try data.makeBytes()
    }
}

protocol Base64URLTranscoding {
    func base64Encode(_: String) -> String?
    func base64URLEncode(_: String) -> String?
}

struct Base64URLTranscoder: Base64URLTranscoding {
    func base64Encode(_ string: String) -> String? {
        var converted = string.utf8CString.map { char -> CChar in
            switch char {
            case 45: // '-'
                return  43 // '+'
            case 95: // '_'
                return 47 // '/'
            default:
                return char
            }
        }
        guard let unpadded = String(utf8String: &converted) else {
            return nil
        }
        
        let characterCount = unpadded.utf8CString.count - 1 // ignore last /0
        let paddingRemainder = (characterCount % 4)
        let paddingCount = paddingRemainder > 0 ? 4 - paddingRemainder : 0
        let padding = Array(repeating: "=", count: paddingCount).joined()
        
        return unpadded + padding
    }
    
    func base64URLEncode(_ string: String) -> String? {
        var converted = string.utf8CString.flatMap { char -> CChar? in
            switch char {
            case 43: // '+'
                return 45 // '-'
            case 47: // '/'
                return 95 // '_'
            case 61: // '='
                return nil
            default:
                return char
            }
        }
        return String(utf8String: &converted)
    }
}

struct Base64Encoding: Encoding {
    
    public init() {}
    
    public func encode(_ bytes: Bytes) throws -> String {
        return bytes.base64String
    }
    
    public func decode(_ base64Encoded: String) throws -> Bytes {
        guard let data = Data(base64Encoded: base64Encoded) else {
            throw JWTError.decoding
        }
        return try data.makeBytes()
    }
}

protocol Encoding {
    func decode(_ : String) throws -> Bytes
    func encode(_ : Bytes) throws -> String
}

extension Encoding {
    func decode(_ string: String) throws -> JSON {
        return try JSON.Parser.parse(string)
        
    }
    
    func encode(_ value: JSON) throws -> String {
        return try value.serialized(options: .init(rawValue: 0))
    }
}

protocol Signer {
    var name: String { get }
    func sign(_ message: Bytes) throws -> Bytes
    func verifySignature(_ signature: Bytes, message: Bytes) throws -> Bool
}

extension Signer {
    public var name: String {
        return String(describing: Self.self)
    }
}

protocol Key {
    var key: Bytes { get }
    init(key: Bytes)
}

extension Key {
    public init(key: String) {
        self.init(key: key.bytes)
    }
    
    init(encodedKey key: String, encoding: Encoding = Base64Encoding()) throws {
        try self.init(key: encoding.decode(key))
    }
}

struct ES256: ECDSASigner {
    public let curve = NID_X9_62_prime256v1
    public let key: Bytes
    public let method = Hash.Method.sha256
    
    public init(key: Bytes) {
        self.key = key
    }
}

struct ES384: ECDSASigner {
    public let curve = NID_secp384r1
    public let key: Bytes
    public let method = Hash.Method.sha384
    
    public init(key: Bytes) {
        self.key = key
    }
}

struct ES512: ECDSASigner {
    public let curve = NID_secp521r1
    public let key: Bytes
    public let method = Hash.Method.sha512
    
    public init(key: Bytes) {
        self.key = key
    }
}

protocol ECDSASigner: Signer, Key {
    var curve: Int32 { get }
    var method: Hash.Method { get }
}

extension ECDSASigner {
    public func sign(_ message: Bytes) throws -> Bytes {
        var digest = try Hash(method, message).hash()
        let ecKey = try newECKeyPair()
        
        guard let signature = ECDSA_do_sign(&digest, Int32(digest.count), ecKey) else {
            throw JWTError.signing
        }
        
        var derEncodedSignature: UnsafeMutablePointer<UInt8>? = nil
        let derLength = i2d_ECDSA_SIG(signature, &derEncodedSignature)
        
        guard let derCopy = derEncodedSignature, derLength > 0 else {
            throw JWTError.signing
        }
        
        var derBytes = [UInt8](repeating: 0, count: Int(derLength))
        
        for b in 0..<Int(derLength) {
            derBytes[b] = derCopy[b]
        }
        
        return derBytes
    }
    
    public func verifySignature(_ der: Bytes, message: Bytes) throws -> Bool {
        var signaturePointer: UnsafePointer? = UnsafePointer(der)
        let signature = d2i_ECDSA_SIG(nil, &signaturePointer, der.count)
        let digest = try Hash(method, message).hash()
        let ecKey = try newECPublicKey()
        let verified = ECDSA_do_verify(digest, Int32(digest.count), signature, ecKey)
        return verified == 1
    }
}

fileprivate extension ECDSASigner {
    func newECKey() throws -> OpaquePointer {
        guard let ecKey = EC_KEY_new_by_curve_name(curve) else {
            throw JWTError.createKey
        }
        return ecKey
    }
    
    func newECKeyPair() throws -> OpaquePointer {
        var privateNum = BIGNUM()
        
        // Set private key
        BN_init(&privateNum)
        BN_bin2bn(key, Int32(key.count), &privateNum)
        let ecKey = try newECKey()
        EC_KEY_set_private_key(ecKey, &privateNum)
        
        // Derive public key
        let context = BN_CTX_new()
        BN_CTX_start(context)
        
        let group = EC_KEY_get0_group(ecKey)
        let publicKey = EC_POINT_new(group)
        EC_POINT_mul(group, publicKey, &privateNum, nil, nil, context)
        EC_KEY_set_public_key(ecKey, publicKey)
        
        // Release resources
        EC_POINT_free(publicKey)
        BN_CTX_end(context)
        BN_CTX_free(context)
        BN_clear_free(&privateNum)
        
        return ecKey
    }
    
    func newECPublicKey() throws -> OpaquePointer {
        var ecKey: OpaquePointer? = try newECKey()
        var publicBytesPointer: UnsafePointer? = UnsafePointer<UInt8>(key)
        
        if let ecKey = o2i_ECPublicKey(&ecKey, &publicBytesPointer, key.count) {
            return ecKey
        } else {
            throw JWTError.createPublicKey
        }
    }
}
