//
//  PunchIn.swift
//  WebPunch
//
//  Created by Keaton Burleson on 4/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CloudKit

struct PunchIn: Punch, CustomStringConvertible, Comparable, Equatable {
    static var recordType: String = "PunchIn"

    var record: CKRecord
    var type: PunchType = .punchIn

    init(record: CKRecord) {
        self.record = record
    }

    init() {
        self.record = CKRecord(recordType: PunchIn.recordType)
        self.record.setValue(Date(), forKey: PunchKeys.at)
    }

    var at: Date {
        get {
            return self.record.value(forKey: PunchKeys.at) as! Date
        }
    }

    var location: CLLocation {
        get {
            return self.record.value(forKey: PunchKeys.location) as! CLLocation
        }
        set {
            self.record.setValue(newValue, forKey: PunchKeys.location)
        }
    }

    var id: CKRecord.ID {
        get {
            return self.record.recordID
        }
    }

    var punchOut: PunchOut? {
        get {
            guard let reference = self.record.value(forKey: PunchKeys.punchOut) as? CKRecord.Reference else {
                return nil
            }

            return PunchModel.sharedInstance.punchesOut.first { punchOut in
                return punchOut.id == reference.recordID
            }
        }
        set {
            guard let newValue = newValue else {
                self.record.setValue(nil, forKey: PunchKeys.punchOut)
                return
            }

            self.record.setValue(CKRecord.Reference(recordID: newValue.record.recordID, action: .none), forKey: PunchKeys.punchOut)
        }
    }

    var description: String {
        guard let validPunchOut = self.punchOut else {
            return "Punched in on \(self.at)"
        }

        return "Punched in on \(self.at). Has matching punch in: \(validPunchOut.at)"
    }

    var totalWorked: TimeInterval {
        get {
            if let validPunchOut = self.punchOut {
                return validPunchOut.at.timeIntervalSince(self.at)
            }

            return Date().timeIntervalSince(self.at)
        }
    }

    var contrastingRecordID: CKRecord.ID? {
        get {
            if let validReference = self.record.value(forKey: PunchKeys.punchOut) as? CKRecord.Reference {
                return validReference.recordID
            }

            return nil
        }
    }

    var constrastingRecordName: String {
        get {
            return "PunchOut"
        }
    }

    var isFlagged: Bool {
        get {
            if let _isFlagged = self.record.value(forKey: PunchKeys.isFlagged) as? Int {
                return _isFlagged != 0
            }
            return false
        }
        set {
            self.record.setValue(newValue ? 1 : 0, forKey: PunchKeys.isFlagged)
        }
    }

    var date: String {
        get {
            let dateFormatter = DateFormatter()

            dateFormatter.dateFormat = "MM/dd"
            return "on \(dateFormatter.string(from: self.at))"
        }
    }

    var time: String {
        get {
            let dateFormatter = DateFormatter()

            dateFormatter.dateFormat = "h:mm a"
            return "at \(dateFormatter.string(from: self.at))"
        }
    }

    static func < (lhs: PunchIn, rhs: PunchIn) -> Bool {
        return lhs.at.compare(rhs.at) == .orderedDescending
    }
    
    func isEqualTo(_ other: Punch) -> Bool {
        return other.id == self.id
    }

    func isGreaterThan(_ other: Punch) -> Bool {
        return self.at.compare(other.at) == .orderedDescending
    }
}
