/*
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Foundation
import CloudKit
import CoreLocation

// Specify the protocol to be used by view controllers to handle notifications.
protocol PunchModelDelegate {
    func errorUpdating(_ error: Error)
    func modelBeginningUpdates()
    func modelEndingUpdates()
}

class PunchModel {
    var records = [CKRecord]()
    var insertedObjects = [Punch]()
    var deletedObjectIds = Set<CKRecord.ID>()
    var useiCloud = true {
        didSet {
            updatePunches()
        }
    }

    let defaults = UserDefaults.init(suiteName: "group.com.webpunch")
    // MARK: - Properties
    let PunchFetchType = "Punch"
    static let sharedInstance = PunchModel()
    var delegate: PunchModelDelegate?
    var punches: [Punch] = []
    var currentPunch: Punch? = nil
    let userInfo: UserInfo

    // Define databases.

    // Represents the default container specified in the iCloud section of the Capabilities tab for the project.
    let container: CKContainer
    let privateDB: CKDatabase

    // MARK: - Initializers
    init() {
        container = CKContainer.default()
        privateDB = container.privateCloudDatabase
        userInfo = UserInfo(container: container)
    }

    @objc func refresh() {
        let query = CKQuery(recordType: Punch.recordType, predicate: NSPredicate(value: true))

        privateDB.perform(query, inZoneWith: nil) { records, error in
            guard let records = records, error == nil else {
                if (error as NSError?)!.code == 9 {
                    self.useiCloud = false
                } else {
                    self.delegate?.errorUpdating(error!)
                }

                self.useiCloud = true
                return
            }

            self.records = records
            self.updatePunches()
        }
    }

    private func updatePunches() {
        DispatchQueue.main.async {
            self.delegate?.modelBeginningUpdates()
        }

        DispatchQueue.main.async {
            if self.useiCloud {
                var knownIds = Set(self.records.map { $0.recordID })

                // remove objects from our local list once we see them returned from the cloudkit storage
                self.insertedObjects.removeAll { punch in
                    knownIds.contains(punch.record.recordID)
                }


                knownIds.formUnion(self.insertedObjects.map { $0.record.recordID })

                // remove objects from our local list once we see them not being returned from storage anymore
                self.deletedObjectIds.formIntersection(knownIds)

                var punches = self.records.map { record in Punch(record: record) }

                if self.insertedObjects.count > 0 {
                    punches.append(contentsOf: self.insertedObjects)
                    punches.removeAll { punch in
                        self.deletedObjectIds.contains(punch.record.recordID)
                    }
                }

                self.punches = punches.sorted(by: { $0.createdAt.compare($1.createdAt) == .orderedDescending })
            } else if let defaults = self.defaults {
                var punches = self.punches

                if self.insertedObjects.count > 0 {
                    punches.append(contentsOf: self.insertedObjects)
                    punches.removeAll { punch in
                        self.deletedObjectIds.contains(punch.record.recordID)
                    }
                }

                defaults.set(punches, forKey: "punches")
                self.punches = punches
            }
        }

        DispatchQueue.main.async {
            self.delegate?.modelEndingUpdates()
        }
    }

    public func punchIn() {
        var newPunch = Punch()
        newPunch.punchType = "In"
        currentPunch = newPunch
        PunchModel.sharedInstance.save(newPunch)
    }

    public func punchOut() {
        var newPunch = Punch()
        newPunch.punchType = "Out"
        currentPunch = newPunch
        PunchModel.sharedInstance.save(newPunch)
    }

    func save(_ punch: Punch) {
        privateDB.save(punch.record) { _, error in
            guard error == nil else {
                self.delegate?.errorUpdating(error!)
                return
            }
            DispatchQueue.main.async {
                self.insertedObjects.append(punch)
                self.updatePunches()
            }
        }
    }

    func punch(_ ref: CKRecord.Reference) -> Punch! {
        let matching = punches.filter { $0.record.recordID == ref.recordID }
        return matching.first
    }

}
