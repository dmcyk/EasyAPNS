//
//  Curl.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 04.07.2016.
//
//
import cURL

public class Curl {
    
    public let rawCurl: UnsafeMutablePointer<Void>
    
    public init() {
        rawCurl = curl_easy_init()
    }
    
    deinit {
        curl_easy_cleanup(rawCurl)
    }
    
    public func set(_ option: CurlSetOption, value: Int) {
        curl_easy_setopt_long(rawCurl, option.raw, value)
    }
    
    public func set(_ option: CurlSetOption, value: UnsafePointer<Int8>) {
        curl_easy_setopt_cstr(rawCurl, option.raw, value)
    }
    
    public func set(_ option: CurlSetOption, value: Int64) {
        curl_easy_setopt_int64(rawCurl, option.raw, value)

    }
    public func setList(_ option: CurlSetOption, value: UnsafeMutablePointer<curl_slist>) {
        curl_easy_setopt_slist(rawCurl, option.raw, value)
    }
    
    public func set(_ option: CurlSetOption, value: UnsafeMutablePointer<Void>) {
        curl_easy_setopt_void(rawCurl, option.raw, value)
    }
    
    public func set(_ option: CurlSetOption, value: Bool) {
        curl_easy_setopt_long(rawCurl, option.raw, value ? 1 : 0)
    }
    
    public func set(_ option: CurlSetOption, optionType: CurlOptionType) {
        switch optionType {
        case .int(let val):
            set(option, value: val)
        case .int64(let val):
            set(option, value: val)
        case .upInt8(let val):
            set(option, value: val)
        case .umpCurlSlist(let val):
            setList(option, value: val)
        case .umpVoid(let val):
            set(option, value: val)
        
        }
    }
    
    public func set(data: [CurlSetOption: CurlOptionType]) {
        data.enumerated().forEach { _, element in
            set(element.key, optionType: element.value)
        }
    }
    
    public func get(_ option: CurlGetOption) -> Int {
        var result = 0
        curl_easy_getinfo_long(rawCurl, option.raw, &result)
        return result
    }
    
    
    public func execute(parseMode: CurlParse = .trimNewLineCharacters) throws -> CurlResponse {
        var response = CurlResponse(parseMode: parseMode)
        let responsePointer = withUnsafeMutablePointer(&response) { UnsafeMutablePointer<Void>($0) }
        
        curl_easy_setopt_void(rawCurl, CURLOPT_HEADERDATA, responsePointer)
        curl_easy_setopt_void(rawCurl, CURLOPT_WRITEDATA, responsePointer)
        curl_easy_setopt_func(rawCurl, CURLOPT_WRITEFUNCTION) { (data, size, nmemb, userData) -> Int in

            if nmemb > 0, let userData = userData {
                let response = UnsafeMutablePointer<CurlResponse>(userData)
                if let characters:UnsafeMutablePointer<CChar> = UnsafeMutablePointer(data) {
                    let buffer = UnsafeMutablePointer<CChar>(allocatingCapacity: size * nmemb + 1)
                    strcpy(buffer, characters)
                    buffer[size * nmemb] = 0
                    var resultString = String(cString: buffer)
                    if case .trimNewLineCharacters = response.pointee.parseMode {
                        resultString.trimHTTPLine()
                    }
                    response.pointee.body.append(resultString)
                    
                    buffer.deinitialize()
                    buffer.deallocateCapacity(size * nmemb + 1)
                }

            }
            
            return size * nmemb
        }
        curl_easy_setopt_func(rawCurl, CURLOPT_HEADERFUNCTION) { (data, size, nmemb, userData) -> Int in
            if nmemb > 0, let userData = userData {
                let response = UnsafeMutablePointer<CurlResponse>(userData)

                if let characters:UnsafeMutablePointer<CChar> = UnsafeMutablePointer(data) {
                    let buffer = UnsafeMutablePointer<CChar>(allocatingCapacity: size * nmemb + 1)
                    strcpy(buffer, characters)
                    buffer[size * nmemb] = 0
                    var resultString = String(cString: buffer)
                    if case .trimNewLineCharacters = response.pointee.parseMode {
                        resultString.trimHTTPLine()
                        
                    }
                    response.pointee.headers.append(resultString)
                    
                    buffer.deinitialize()
                    buffer.deallocateCapacity(size * nmemb + 1)
                }
                
            }
            return size * nmemb
        }
        let start = curl_easy_perform(rawCurl)
        
        if start != CURLE_OK {
            throw CurlErr(err: start.rawValue, description: String(cString: curl_easy_strerror(start)))
        }
        
        if case .trimNewLineCharacters = parseMode {
            // HTTP headers are separated by one empty line contating only CRLF
            let _ = response.headers.popLast()
        }

        
        response.code = get(.httpResponseCode)
        
        return response
    }
    
}






