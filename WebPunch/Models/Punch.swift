//
//  Punch.swift
//  WebPunch
//
//  Created by Keaton Burleson on 4/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit
import CloudKit

struct Punch: CustomStringConvertible, Equatable {
    static func == (lhs: Punch, rhs: Punch) -> Bool {
        return lhs.punchDate == rhs.punchDate && lhs.punchTime == rhs.punchTime && lhs.punchType == rhs.punchType
    }

    static let recordType = "Punch"

    // MARK: - Properties
    var record: CKRecord!
    private (set) public var createdAt: Date!
    weak var database: CKDatabase!


    var description: String {
        return "Punch \(punchDate) - \(self.punchType)"
    }

    var punchDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd"
        let formattedDate = dateFormatter.string(from: self.createdAt)

        return "on \(formattedDate)"
    }

    var punchTime: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"
        let formattedDate = dateFormatter.string(from: self.createdAt)

        return "at \(formattedDate)"
    }

    var punchType: String {
        get {
            return self.getPunchType().stringValue
        }
        set {
            var newType = 0
            if newValue == "In" {
                newType = 1
            } else if newValue == "Out" {
                newType = 2
            }
            self.record.setValue(newType, forKey: "type")
        }
    }

    // MARK: - Initializers
    init(record: CKRecord) {
        let container = CKContainer.default()
        self.database = container.privateCloudDatabase
        //  privateDB = container.privateCloudDatabas

        self.record = record
        self.createdAt = record.creationDate
        print(record)
    }

    init() {
        let container = CKContainer.default()
        self.database = container.privateCloudDatabase
        self.createdAt = Date()
        self.record = CKRecord(recordType: Punch.recordType)
    }

    func getPunchType() -> PunchType {
        let punchType = record["type"] as? NSNumber
        var val: UInt = 0
        guard let punchTypeNum = punchType else {
            return PunchType(rawValue: val)
        }
        val = punchTypeNum.uintValue
        return PunchType(rawValue: val)
    }
}
