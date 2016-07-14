//
//  Queue+Collection.swift
//  EasyAPNS
//
//  Created by Damian Malarczyk on 13.07.2016.
//
//


extension Queue: Collection {
    public typealias Index = Int
    public var startIndex: Int { return 0 }
    public var endIndex: Int { return array.count }
    
    public subscript(idx: Int) -> T? {
        guard idx < endIndex else { fatalError("Index out of bounds of queue") }
        return array[idx]
    }
    
    public func index(after i: Index) -> Index {
        return i + 1
    }
}
