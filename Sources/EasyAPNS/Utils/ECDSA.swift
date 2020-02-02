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
import OpenCrypto
import COpenCryptoOpenSSL
import COpenCrypto

public enum JWTError: Error {
  case decoding, encoding
  case signing, createKey, createPublicKey
  case signatureVerificationFailed
}

protocol Encoding {
  func decode(_: String) throws -> Data
  func encode(_: Data) throws -> String
}

protocol Signer {
  var name: String { get }
  func sign(message: Data) throws -> Data
  func verify(signature: Data, message: Data) throws
}

extension Signer {
  var name: String { return String(describing: Self.self) }

  func sign(message bytes: Data) throws -> Data {
    return try sign(message: bytes)
  }

  func verify(signature: Data, message: Data) throws {
    return try verify(signature: signature, message: message)
  }
}

final class ES256: ECDSASigner {
  typealias HashFcn = SHA256
  let curve = NID_X9_62_prime256v1
  let key: Data

  init(key: Data) { self.key = key }
}

final class ES384: ECDSASigner {
  typealias HashFcn = SHA256
  let curve = NID_secp384r1
  let key: Data

  init(key: Data) { self.key = key }
}

final class ES512: ECDSASigner {
  let curve = NID_secp521r1
  let key: Data
  typealias HashFcn = SHA512

  public init(key: Data) { self.key = key }
}

protocol ECDSASigner: Signer {
  associatedtype HashFcn: HashFunction
  var key: Data { get }
  var curve: Int32 { get }
  init(key: Data)
}

extension ECDSASigner {
  init(bytes: Data) { self.init(key: bytes) }

  func makeBytes() -> Data { return key }
}

extension ECDSASigner {
  fileprivate func hash(_ data: Data) -> Data {
    var fcn = HashFcn()
    fcn.update(data: data)
    return Data(fcn.finalize())
  }

  func sign(message: Data) throws -> Data {
    let digest = hash(message)
    return try digest.withByteBuffer { digestBytes in
      let ecKey = try newECKeyPair()

      guard
        let signature = ECDSA_do_sign(
          digestBytes.baseAddress,
          Int32(digestBytes.count),
          ecKey
        )
      else { throw JWTError.signing }

      var derEncodedSignature: UnsafeMutablePointer<UInt8>? = nil
      let derLength = i2d_ECDSA_SIG(signature, &derEncodedSignature)

      guard let derCopy = derEncodedSignature, derLength > 0 else {
        throw JWTError.signing
      }

      var derBytes = Data(count: Int(derLength))

      for b in 0..<Int(derLength) { derBytes[b] = derCopy[b] }

      return derBytes
    }
  }

  func verify(signature der: Data, message: Data) throws {
    try der.withByteBuffer { buffer in
      var signaturePointer: UnsafePointer? = buffer.baseAddress
      let signature = d2i_ECDSA_SIG(nil, &signaturePointer, der.count)
      try hash(message).withByteBuffer { digestBytes in
        let ecKey = try newECPublicKey()
        let verified = ECDSA_do_verify(
          digestBytes.baseAddress,
          Int32(digestBytes.count),
          signature,
          ecKey
        )
        guard verified == 1 else { throw JWTError.signatureVerificationFailed }
      }
    }
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
    // Set private key
    return try key.withByteBuffer { keyBuffer in
      let privateNum = BN_secure_new()
      BN_bin2bn(keyBuffer.baseAddress, Int32(key.count), privateNum)
      let ecKey = try newECKey()
      EC_KEY_set_private_key(ecKey, privateNum)

      // Derive public key
      let context = BN_CTX_new()
      BN_CTX_start(context)

      let group = EC_KEY_get0_group(ecKey)
      let publicKey = EC_POINT_new(group)
      EC_POINT_mul(group, publicKey, privateNum, nil, nil, context)
      EC_KEY_set_public_key(ecKey, publicKey)

      // Release resources
      EC_POINT_free(publicKey)
      BN_CTX_end(context)
      BN_CTX_free(context)
      BN_clear_free(privateNum)

      return ecKey
    }
  }

  func newECPublicKey() throws -> OpaquePointer {
    return try key.withByteBuffer { buffer in
      var ecKey: OpaquePointer? = try newECKey()
      var publicBytesPointer: UnsafePointer? = UnsafePointer<UInt8>(
        buffer.baseAddress
      )

      if let ecKey = o2i_ECPublicKey(&ecKey, &publicBytesPointer, key.count) {
        return ecKey
      } else { throw JWTError.createPublicKey }
    }
  }
}
