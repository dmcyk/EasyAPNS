//
//  Utils.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 04.07.2016.
//
//

import Foundation

public extension String {
  func among(_ l: String, _ r: String) -> String? {
    guard let lRange = range(of: l), let rRange = range(of: r),
      lRange.upperBound < rRange.lowerBound
    else { return nil }

    return self[lRange.upperBound..<rRange.lowerBound].trimmingCharacters(
      in: .whitespacesAndNewlines
    )
  }

  func split(withLength length: Int) -> [String] {
    var start = self.startIndex
    var res: [String] = []

    while distance(from: start, to: self.endIndex) > length {
      let next = self.index(start, offsetBy: length)
      res.append(String(self[start..<next]))
      start = next
    }

    if distance(from: start, to: self.endIndex) > 0 {
      res.append(String(self[start..<self.endIndex]))
    }
    return res
  }

  func flop(character: String) -> String {
    return components(separatedBy: .newlines).map {
      $0.trimmingCharacters(in: .whitespacesAndNewlines).components(
        separatedBy: .whitespaces
      ).filter { x in !x.isEmpty }.joined(separator: character)
    }.joined(separator: "\n")
  }

  var bytesCount: Int { return utf8.count }
}

public extension Array {

  func split(withLength length: Int) -> [[Element]] {
    var start = self.startIndex
    var res: [[Element]] = []

    while distance(from: start, to: self.endIndex) > length {
      let next = self.index(start, offsetBy: length)
      res.append(Array(self[start..<next]))
      start = next
    }

    if distance(from: start, to: self.endIndex) > 0 {
      res.append(Array(self[start..<self.endIndex]))
    }
    return res
  }
}

extension String {

  func convertToData() -> Data {
    return Data(utf8)
  }
}

extension FileHandle {

  enum Error: Swift.Error {
    case tmpFileFailure
  }

  static func createTempFile() throws -> FileHandle {
    let template = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("tmp_file_easy_apn.XXXXXX").path
    let buffer: UnsafeMutableBufferPointer<Int8> = template.withCString {
      let len = strlen($0)
      let buffer = UnsafeMutableBufferPointer<Int8>.allocate(capacity: len + 1)
      buffer[len] = 0
      _ = buffer.initialize(
        from: UnsafeBufferPointer<Int8>(start: $0, count: len)
      )
      return buffer
    }

    let fd = mkstemp(buffer.baseAddress)
    if fd == -1 {
      throw Error.tmpFileFailure
    }

    // buffer.deintialize?
    buffer.baseAddress?.deinitialize(count: buffer.count)
    buffer.deallocate()

    return FileHandle(fileDescriptor: fd, closeOnDealloc: true)
  }
}

extension Data {
  public func withByteBuffer<T>(
    _ closure: (UnsafeBufferPointer<UInt8>) throws -> T
  )
    rethrows -> T
  {
    return try self.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
      return try closure(buffer.bindMemory(to: UInt8.self))
    }
  }
}
