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

import Foundation
import CTLS
import Crypto

public enum JWTError: Error {
  case decoding, encoding
  case signing, createKey, createPublicKey
  case signatureVerificationFailed
}

protocol Encoding {
  func decode(_: String) throws -> Bytes
  func encode(_: Bytes) throws -> String
}
//
//extension Encoding {
//    func decode(_ string: String) throws -> JSON {
//        return try JSON.Parser.parse(string)
//        
//    }
//    
//    func encode(_ value: JSON) throws -> String {
//        return try value.serialized(options: .init(rawValue: 0))
//    }
//}

protocol Signer {
  var name: String { get }
  func sign(message: Bytes) throws -> Bytes
  func verify(signature: Bytes, message: Bytes) throws
}

extension Signer {
  var name: String { return String(describing: Self.self) }

  func sign(message convertible: BytesConvertible) throws -> Bytes {
    let bytes = try convertible.makeBytes()
    return try sign(message: bytes)
  }

  func verify(signature: BytesConvertible, message: BytesConvertible) throws {
    let signatureBytes = try signature.makeBytes()
    let messageBytes = try message.makeBytes()
    return try verify(signature: signatureBytes, message: messageBytes)
  }
}

final class ES256: ECDSASigner {
  let curve = NID_X9_62_prime256v1
  let key: Bytes
  let method = Hash.Method.sha256

  init(key: Bytes) { self.key = key }
}

final class ES384: ECDSASigner {
  let curve = NID_secp384r1
  let key: Bytes
  let method = Hash.Method.sha384

  init(key: Bytes) { self.key = key }
}

final class ES512: ECDSASigner {
  let curve = NID_secp521r1
  let key: Bytes
  let method = Hash.Method.sha512

  public init(key: Bytes) { self.key = key }
}

protocol ECDSASigner: Signer, BytesConvertible {
  var key: Bytes { get }
  var curve: Int32 { get }
  var method: Hash.Method { get }
  init(key: Bytes)
}

extension ECDSASigner {
  init(bytes: Bytes) { self.init(key: bytes) }

  func makeBytes() -> Bytes { return key }
}

extension ECDSASigner {
  func sign(message: Bytes) throws -> Bytes {
    var digest = try Hash(method, message).hash()
    let ecKey = try newECKeyPair()

    guard let signature = ECDSA_do_sign(&digest, Int32(digest.count), ecKey)
    else { throw JWTError.signing }

    var derEncodedSignature: UnsafeMutablePointer<UInt8>? = nil
    let derLength = i2d_ECDSA_SIG(signature, &derEncodedSignature)

    guard let derCopy = derEncodedSignature, derLength > 0 else {
      throw JWTError.signing
    }

    var derBytes = [UInt8](repeating: 0, count: Int(derLength))

    for b in 0..<Int(derLength) { derBytes[b] = derCopy[b] }

    return derBytes
  }

  func verify(signature der: Bytes, message: Bytes) throws {
    var signaturePointer: UnsafePointer? = UnsafePointer(der)
    let signature = d2i_ECDSA_SIG(nil, &signaturePointer, der.count)
    let digest = try Hash(method, message).hash()
    let ecKey = try newECPublicKey()
    let verified = ECDSA_do_verify(
      digest,
      Int32(digest.count),
      signature,
      ecKey
    )
    guard verified == 1 else { throw JWTError.signatureVerificationFailed }
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
    } else { throw JWTError.createPublicKey }
  }
}
