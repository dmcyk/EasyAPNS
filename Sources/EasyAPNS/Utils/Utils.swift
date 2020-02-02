//
//  Utils.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 04.07.2016.
//
//

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
