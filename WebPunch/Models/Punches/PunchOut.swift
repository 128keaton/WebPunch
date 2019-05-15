//
//  PunchOut.swift
//  WebPunch
//
//  Created by Keaton Burleson on 5/14/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import CloudKit

struct PunchOut: Punch, CustomStringConvertible, Comparable, Equatable {
    static var recordType: String = "PunchOut"

    var record: CKRecord
    var type: PunchType = .punchOut

    init(record: CKRecord) {
        self.record = record
    }

    init() {
        self.record = CKRecord(recordType: PunchOut.recordType)
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

    var punchIn: PunchIn? {
        get {
            guard let reference = self.record.value(forKey: PunchKeys.punchIn) as? CKRecord.Reference else {
                return nil
            }

            return PunchModel.sharedInstance.punchesIn.first { $0.record.recordID == reference.recordID }
        }
        set {
            guard let newValue = newValue else {
                self.record.setValue(nil, forKey: PunchKeys.punchIn)
                return
            }

            self.record.setValue(CKRecord.Reference(recordID: newValue.record.recordID, action: .none), forKey: PunchKeys.punchIn)
        }
    }

    var description: String {
        guard let validPunchIn = self.punchIn else {
            return "Punched out on \(self.at)"
        }

        return "Punched out on \(self.at). Has matching punch in: \(validPunchIn.at)"
    }

    var totalWorked: TimeInterval {
        get {
            if let validPunchIn = self.punchIn {
                return self.at.timeIntervalSince(validPunchIn.at)
            }
            return 0.0
        }
    }

    var contrastingRecordID: CKRecord.ID? {
        get {
            if let validReference = self.record.value(forKey: PunchKeys.punchIn) as? CKRecord.Reference {
                return validReference.recordID
            }

            return nil
        }
    }

    var constrastingRecordName: String {
        get {
            return "PunchIn"
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
    
    var time: String{
        get {
            let dateFormatter = DateFormatter()
            
            dateFormatter.dateFormat = "h:mm a"
            return "at \(dateFormatter.string(from: self.at))"
        }
    }

    static func < (lhs: PunchOut, rhs: PunchOut) -> Bool {
        return lhs.at.compare(rhs.at) == .orderedDescending
    }
    
    func isEqualTo(_ other: Punch) -> Bool {
        return other.id == self.id
    }
    
    func isGreaterThan(_ other: Punch) -> Bool {
        return self.at.compare(other.at) == .orderedDescending
    }
}
