//
//  GenericsExtension.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import Foundation

//  Enable @AppStorage for [Codable]
extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
            let result = try? JSONDecoder().decode([Element].self, from: data)
        else { return nil }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
            let result = String(data: data, encoding: .utf8)
        else { return "[]" }
        return result
    }
}

// Access Array with ...[safe: index] -> Element? to avoid index out of range issue
extension Collection where Indices.Iterator.Element == Index {
    public subscript(safe index: Index) -> Iterator.Element? {
        (startIndex <= index && index < endIndex) ? self[index] : nil
    }
}

// Provide .next() methof for CaseIterable
extension CaseIterable where Self: Equatable {
    func next() -> Self {
        let all = Self.allCases
        let idx = all.firstIndex(of: self)!
        let next = all.index(after: idx)
        return all[next == all.endIndex ? all.startIndex : next]
    }
}

// Shorthand to convert array to dict, like group in pandas
extension Sequence {
    public func categorise<U: Hashable>(_ key: (Iterator.Element) -> U) -> [U:
        [Iterator.Element]]
    {
        var dict: [U: [Iterator.Element]] = [:]
        for el in self {
            let key = key(el)
            if case nil = dict[key]?.append(el) { dict[key] = [el] }
        }
        return dict
    }
}

infix operator %%

extension Int {
    static func %% (_ left: Int, _ right: Int) -> Int {
        if left >= 0 { return left % right }
        if left >= -right { return (left + right) }
        return ((left % right) + right) % right
    }
}
