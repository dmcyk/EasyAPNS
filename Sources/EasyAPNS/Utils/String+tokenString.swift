//
//  String+tokenString.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 31.01.2017.
//
//

import Foundation
import Core
import CTLS

public enum TokenError: Error {
    case invalidAuthKey
    case invalidTokenString
    case errorCreatingTemporaryKeyFile
    case dataError
}

extension UnsafeMutablePointer {
    
    func buffer(withLength length: Int) -> [Pointee] {
        return (0 ..< length).map {
            self[$0]
        }
    }
}

extension String {
    
    func tokenString() throws -> (privateKey: Bytes, publicKey: Bytes?) {
        
        let fileString = try String(contentsOfFile: self, encoding: .utf8)
        
        let beginPrivateKey = "-----BEGIN PRIVATE KEY-----"
        let endPrivateKey = "-----END PRIVATE KEY-----"
        guard let privateKeyString = fileString
            .among(beginPrivateKey, endPrivateKey)?
            .flop(character: " ")
            .components(separatedBy: .newlines)
            .joined(separator: "")
            else {
                throw TokenError.invalidTokenString
        }
        let newKeyContent = "\(beginPrivateKey)\n\(privateKeyString.split(withLength: 64).joined(separator: "\n"))\n\(endPrivateKey)"
        
        let tmpFile = "\(self).tmp"
        try newKeyContent.write(toFile: tmpFile, atomically: true, encoding: .utf8)
        
        var pKey = EVP_PKEY_new()
        
        let fp = fopen(tmpFile, "r")
        
        guard fp != nil else {
            throw TokenError.errorCreatingTemporaryKeyFile
        }
        
        PEM_read_PrivateKey(fp, &pKey, nil, nil)
        
        fclose(fp)
        
        try FileManager.default.removeItem(atPath: tmpFile)
        
        
        let ecKey = EVP_PKEY_get1_EC_KEY(pKey)
        
        EC_KEY_set_conv_form(ecKey, POINT_CONVERSION_UNCOMPRESSED)
        
        var pub: UnsafeMutablePointer<UInt8>? = nil
        
        let pub_len = i2o_ECPublicKey(ecKey, &pub)
        
        let publicKey: Bytes? = pub?.buffer(withLength: Int(pub_len))
        
        let bn = EC_KEY_get0_private_key(ecKey!)
        
        guard let privKeyBigNum = BN_bn2hex(bn) else {
            throw TokenError.dataError
        }
        
        let privateKey = "00\(String(validatingUTF8: privKeyBigNum)!)"
        var build = privateKey
        
        for _ in 0 ..< 100 {
            build += privateKey
        }
        
        CRYPTO_free(privKeyBigNum)
        EVP_PKEY_free(pKey)
        
        guard let privData = privateKey.hexToData() else {
            throw TokenError.dataError
        }
        
        return (privData.makeBytes(), publicKey)
    }
    
    // http://codereview.stackexchange.com/questions/135424/hex-string-to-bytes-nsdata
    func hexToData() -> Data? {
        
        // Convert 0 ... 9, a ... f, A ...F to their decimal value,
        // return nil for all other input characters
        func decodeNibble(u: UInt16) -> UInt8? {
            switch(u) {
            case 0x30 ... 0x39:
                return UInt8(u - 0x30)
            case 0x41 ... 0x46:
                return UInt8(u - 0x41 + 10)
            case 0x61 ... 0x66:
                return UInt8(u - 0x61 + 10)
            default:
                return nil
            }
        }
        
        let utf16 = self.utf16
        var data = Data(capacity: utf16.count/2)
        
        var i = utf16.startIndex
        while i != utf16.endIndex {
            guard let
                hi = decodeNibble(u: utf16[i]),
                let lo = decodeNibble(u: utf16[utf16.index(i, offsetBy: 1)])
                else {
                    return nil
            }
            var value = hi << 4 + lo
            data.append(&value, count: 1)
            i = utf16.index(i, offsetBy: 2)
        }
        return data
    }
}
