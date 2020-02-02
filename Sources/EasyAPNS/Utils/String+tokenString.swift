//
//  String+tokenString.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 31.01.2017.
//
//

import Foundation
import COpenCrypto
import COpenCryptoOpenSSL
import COpenSSLBridge

public enum TokenError: Error {
  case invalidAuthKey
  case invalidTokenString
  case dataError
  case keyInitialisationError
  case publicKeyInitialisationError
}

extension String {
  func tokenString() throws -> (privateKey: Data, publicKey: Data?) {
    let fileString = try String(contentsOfFile: self, encoding: .utf8)
    let beginPrivateKey = "-----BEGIN PRIVATE KEY-----"
    let endPrivateKey = "-----END PRIVATE KEY-----"
    guard
      let privateKeyString = fileString.among(beginPrivateKey, endPrivateKey)?
        .flop(character: " ").components(separatedBy: .newlines).joined(
          separator: ""
        )
    else { throw TokenError.invalidTokenString }

    // new key
    let newKeyContent =
      "\(beginPrivateKey)\n\(privateKeyString.split(withLength: 64).joined(separator: "\n"))\n\(endPrivateKey)"

    // read key from tmp file
    var pKey = EVP_PKEY_new()
    do {
      try withExtendedLifetime(FileHandle.createTempFile()) { tmpFile in
        tmpFile.write(newKeyContent.convertToData())
        tmpFile.seek(toFileOffset: 0)

        let rawFile = fdopen(tmpFile.fileDescriptor, "r")
        precondition(rawFile != nil)
        PEM_read_PrivateKey(rawFile, &pKey, nil, nil)
      }
    }

    // key
    guard
      let ecKey:OpaquePointer = (
        {
          let ecKey = EVP_PKEY_get1_EC_KEY(pKey)
          EC_KEY_set_conv_form(ecKey, POINT_CONVERSION_UNCOMPRESSED)
          return ecKey
        }()
      )
    else {
      throw TokenError.keyInitialisationError
    }

    // public key
    let pubKey: Data = try {
      // https://github.com/openssl/openssl/blob/master/crypto/ec/ec_ameth.c
      var pubLen = Int(i2o_ECPublicKey(ecKey, nil))
      // first extract length
      guard pubLen > 0 else {
        throw TokenError.publicKeyInitialisationError
      }

      // only then initialise buffer and get contents
      let pubKey: UnsafeMutablePointer<UInt8> = bridge_openssl_malloc(pubLen)
      var pubKeyEnd: UnsafeMutablePointer<UInt8>? = pubKey
      pubLen = Int(i2o_ECPublicKey(ecKey, &pubKeyEnd))
      guard pubLen > 0 else {
        throw TokenError.publicKeyInitialisationError
      }

      // copy data and free original buffer
      let publicKey = Data(bytes: pubKey, count: Int(pubLen))
      bridge_openssl_free_unsigned(pubKey)
      return publicKey
    }()

    let privKey: Data = try {
      let bn = EC_KEY_get0_private_key(ecKey)
      guard let privKeyBigNum = BN_bn2hex(bn) else {
        throw TokenError.dataError
      }

      let privKey = try String.cHEXStringToData(
        buffer: UnsafeBufferPointer<Int8>(
          start: privKeyBigNum,
          count: strlen(privKeyBigNum)
        )
      )
      bridge_openssl_free(privKeyBigNum)
      return privKey
    }()

    EVP_PKEY_free(pKey)

    return (privKey, pubKey)
  }

  struct NotHexString: Error {}

  static public func cHEXStringToData(buffer: UnsafeBufferPointer<Int8>) throws
    -> Data
  {
    func asciiToDecimal(u: Int8) throws -> UInt8 {
      switch (u) {
      case 0x30...0x39: return UInt8(u - 0x30)
      case 0x41...0x46: return UInt8(u - 0x41 + 10)
      case 0x61...0x66: return UInt8(u - 0x61 + 10)
      default: throw NotHexString()
      }
    }

    guard buffer.count % 2 == 0 else {
      throw NotHexString()
    }

    var data = Data(count: buffer.count / 2)

    var i = 0
    var nth = 0
    while i != buffer.count {
      let hi = try asciiToDecimal(u: buffer[i])
      i += 1
      data[nth] = try hi << 4 + asciiToDecimal(u: buffer[i])
      nth += 1
      i += 1
    }
    return data
  }
}
