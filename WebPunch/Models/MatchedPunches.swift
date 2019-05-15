//
//  MatchedPunches.swift
//  WebPunch
//
//  Created by Keaton Burleson on 5/14/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

struct MatchedPunches: Equatable, Collection {
    let punches: [OperationalPunch]
    let key: Date

    typealias Index = Int

    var startIndex: Int {
        return punches.startIndex
    }

    var endIndex: Int {
        return punches.endIndex
    }

    subscript(i: Int) -> OperationalPunch {
        return punches[i]
    }

    public func index(after i: Int) -> Int {
        return punches.index(after: i)
    }

    static func == (fst: MatchedPunches, snd: MatchedPunches) -> Bool {
        return fst.key == snd.key
    }
}
