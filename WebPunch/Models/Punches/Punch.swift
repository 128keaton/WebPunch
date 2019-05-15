//
//  Punch.swift
//  WebPunch
//
//  Created by Keaton Burleson on 5/14/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CloudKit

protocol Punch {
    static var recordType: String { get set }

    var record: CKRecord { get set }
    var at: Date { get }
    var location: CLLocation { get set }
    var id: CKRecord.ID { get }
    var contrastingRecordID: CKRecord.ID? { get }
    var constrastingRecordName: String { get }
    var totalWorked: TimeInterval { get }
    var isFlagged: Bool { set get }
    var time: String { get }
    var date: String { get }
    var type: PunchType { get }

    func isEqualTo(_ other: Punch) -> Bool
    func isGreaterThan(_ other: Punch) -> Bool
}

enum PunchType: String {
    case punchIn = "in"
    case punchOut = "out"
    case invalid = "invalid"
}


extension Punch where Self: Equatable {
    func isEqualTo(_ other: Punch) -> Bool {
        guard let otherPunch = other as? Self else { return false }
        return self == otherPunch
    }
}

extension Punch where Self: Comparable {
    func isGreaterThan(_ other: Punch) -> Bool {
        guard let otherPunch = other as? Self else { return false }
        return self.at.compare(otherPunch.at) == .orderedDescending
    }
}

extension Punch {
    func isSameDay(_ other: Punch) -> Bool {
        guard let otherPunch = other as? Self else { return false }
        return Calendar.current.isDate(self.at, inSameDayAs: otherPunch.at)
    }
    
    func isSameDay(_ other: Date) -> Bool {
        return Calendar.current.isDate(self.at, inSameDayAs: other)
    }
}

extension OperationalPunch: Equatable, Comparable {
    static func < (lhs: OperationalPunch, rhs: OperationalPunch) -> Bool {
        return lhs.punch.isGreaterThan(rhs.punch)
    }

    static func == (lhs: OperationalPunch, rhs: OperationalPunch) -> Bool {
        return lhs.punch.isEqualTo(rhs.punch)
    }
}

struct OperationalPunch: Punch {
    static var recordType: String = "Punch"

    init(_ punch: Punch) {
        self.punch = punch
    }

    var record: CKRecord {
        get {
            return self.punch.record
        }
        set {
            self.punch.record = newValue
        }
    }

    var type: PunchType {
        return self.punch.type
    }

    var at: Date {
        return self.punch.at
    }

    var location: CLLocation {
        get {
            return self.punch.location
        }
        set {
            self.punch.location = newValue
        }
    }

    var id: CKRecord.ID {
        return self.punch.id
    }

    var totalWorked: TimeInterval {
        return self.punch.totalWorked
    }

    var contrastingRecordID: CKRecord.ID? {
        return self.punch.contrastingRecordID
    }

    var constrastingRecordName: String {
        return self.punch.constrastingRecordName
    }

    var isFlagged: Bool {
        get {
            return self.punch.isFlagged
        }
        set {
            self.punch.isFlagged = newValue
        }
    }

    var date: String {
        return self.punch.date
    }

    var time: String {
        return self.punch.time
    }

    private var punch: Punch
}
