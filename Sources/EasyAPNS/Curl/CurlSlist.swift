//
//  Slist.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 07.07.2016.
//
//
import cURL

public final class CurlSlist {
    public private(set) var rawSlist: UnsafeMutablePointer<curl_slist>! = nil
    
    public init?(fromArray: [String]) {
        var slist: UnsafeMutablePointer<curl_slist>? = nil
        fromArray.forEach {
            let _ = $0.withCString { str in
                slist = curl_slist_append(slist, str)
            }
        }
        if slist == nil {
            return nil
        }
        rawSlist = slist
    }
    
    public func append(element: String) {
        rawSlist = curl_slist_append(rawSlist, element)
    }
    
    deinit {
        curl_slist_free_all(rawSlist)
    }
}
