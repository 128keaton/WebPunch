//
//  PunchType.swift
//  WebPunch
//
//  Created by Keaton Burleson on 4/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit


struct PunchType: OptionSet {

    // MARK: - Properties
    var rawValue: UInt = 0

    var boolValue: Bool {
        return self.rawValue != 0
    }

    // MARK: - Initializer
    init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    init(nilLiteral: ()) {
        self.rawValue = 0
    }

    // MARK: - Methods
    func toRaw() -> UInt {
        return self.rawValue
    }

    var stringValue: String {
        if intersection(.Out).boolValue {
            return "Out"
        } else if intersection(.In).boolValue {
            return "In"
        }
        return "Invalid"
    }
}

// MARK: - Static
extension PunchType {

    // MARK: - Properties
    static var In: PunchType {
        return self.init(rawValue: 1 << 0)
    }

    static var Out: PunchType {
        return self.init(rawValue: 1 << 1)
    }

    static var Invalid: PunchType {
        return self.init(rawValue: 0)
    }


    // MARK: - Methods
    static func convertFromNilLiteral() -> PunchType {
        return .Invalid
    }

    static func fromRaw(_ raw: UInt) -> PunchType? {
        return self.init(rawValue: raw)
    }

    static func fromMask(_ raw: UInt) -> PunchType {
        return self.init(rawValue: raw)
    }
}

func == (lhs: PunchType, rhs: PunchType) -> Bool {
    return lhs.rawValue == rhs.rawValue
}

func | (lhs: PunchType, rhs: PunchType) -> PunchType {
    return PunchType(rawValue: lhs.rawValue | rhs.rawValue)
}

func & (lhs: PunchType, rhs: PunchType) -> PunchType {
    return PunchType(rawValue: lhs.rawValue & rhs.rawValue)
}

func ^ (lhs: PunchType, rhs: PunchType) -> PunchType {
    return PunchType(rawValue: lhs.rawValue ^ rhs.rawValue)
}
