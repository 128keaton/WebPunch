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
    static let modelUpdatesEnding = Notification.Name("PunchModelUpdatesEnding")
    static let modelUpdatesBeginning = Notification.Name("PunchModelUpdatesBeginning")
    static let handleModelError = Notification.Name("PunchModelHandleError")
    static let didPunchIn = Notification.Name("PunchModelDidPunchIn")
    static let didPunchInTesting = Notification.Name("PunchModelDidPunchInTesting")

    var useiCloud = true {
        didSet {
            updatePunches()
        }
    }

    // MARK: - Properties
    let PunchFetchType = "Punch"
    let userInfo: UserInfo

    private (set) public var punches: [Punch] = []
    private (set) public var weekPayPeriods: [WeekPayPeriod] = []
    private (set) public var dayPayPeriods: [DayPayPeriod] = []
    private (set) public var fullPayPeriods: [FullPayPeriod] = []

    private var currentPunch: Punch? = nil
    private var records = [CKRecord]()
    private var insertedObjects = [Punch]()
    private var deletedObjectIds = Set<CKRecord.ID>()

    static let sharedInstance = PunchModel()

    private let calendar = Calendar(identifier: .gregorian)
    private let defaults = UserDefaults.init(suiteName: "group.com.webpunch")

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
                } else if let updateError = error {
                    NotificationCenter.default.post(name: PunchModel.handleModelError, object: updateError)
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
            NotificationCenter.default.post(name: PunchModel.modelUpdatesBeginning, object: nil)
        }

        DispatchQueue.main.async {
            self.weekPayPeriods = []

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

                self.punches = self.sortPunches(punches)
            }

            self.dayPayPeriods = self.matchIntoDailyPayPeriods()
            self.weekPayPeriods = self.matchIntoWeeklyPayPeriods()
            self.fullPayPeriods = self.matchIntoFullPayPeriods()
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: PunchModel.modelUpdatesEnding, object: nil)
        }
    }

    public func punchIn() {
        var newPunch = Punch()
        newPunch.punchType = "In"
        currentPunch = newPunch
        NotificationCenter.default.post(name: PunchModel.didPunchIn, object: newPunch.punchID)
        PunchModel.sharedInstance.save(newPunch)
    }

    public func punchOut() {
        var newPunch = Punch()
        newPunch.punchType = "Out"
        currentPunch = newPunch
        PunchModel.sharedInstance.save(newPunch)
    }

    func save(_ punch: Punch) {
        if useiCloud {
            privateDB.save(punch.record) { _, error in
                if let saveError = error {
                    NotificationCenter.default.post(name: PunchModel.handleModelError, object: saveError)
                }
                DispatchQueue.main.async {
                    self.insertedObjects.append(punch)
                    self.updatePunches()
                }
            }
        } else {
            // TODO
        }
    }

    func punch(_ ref: CKRecord.Reference) -> Punch! {
        let matching = punches.filter { $0.record.recordID == ref.recordID }
        return matching.first
    }

    // MARK: Helper methods

    private func sortPunches(_ newPunches: [Punch]) -> [Punch] {
        return newPunches.sorted(by: { $0.createdAt.compare($1.createdAt) == .orderedDescending })
    }

    private func matchIntoWeeklyPayPeriods() -> [WeekPayPeriod] {
        var payPeriods = [WeekPayPeriod]()

        for punch in self.punches {
            let firstDateOfWeek = punch.createdAt.firstDateofWeekFromSelf
            var currentPayPeriod: WeekPayPeriod? = nil

            if let existingPayPeriod = (payPeriods.first { Calendar.current.compare($0.weekOf, to: firstDateOfWeek, toGranularity: .day) == .orderedSame }) {
                currentPayPeriod = existingPayPeriod
                currentPayPeriod?.addPunch(newPunch: punch)
            } else {
                currentPayPeriod = WeekPayPeriod(punch: punch, weekOf: firstDateOfWeek)
                payPeriods.append(currentPayPeriod!)
            }
        }

        return payPeriods
    }

    private func matchIntoDailyPayPeriods() -> [DayPayPeriod] {
        var payPeriods = [DayPayPeriod]()

        for punch in self.punches {
            var currentPayPeriod: DayPayPeriod? = nil

            if let existingPayPeriod = (payPeriods.first { Calendar.current.compare($0.day, to: punch.createdAt, toGranularity: .day) == .orderedSame }) {
                currentPayPeriod = existingPayPeriod
                currentPayPeriod?.addPunch(newPunch: punch)
            } else {
                currentPayPeriod = DayPayPeriod(punch: punch, day: punch.createdAt)
                payPeriods.append(currentPayPeriod!)
            }
        }

        return payPeriods
    }

    private func matchIntoFullPayPeriods() -> [FullPayPeriod] {
        var payPeriods = [FullPayPeriod]()
        self.weekPayPeriods.chunked(into: 2).forEach {
            if ($0.count <= 2) {
                payPeriods.append(FullPayPeriod(bothWeeks: $0))
            }
        }
        return payPeriods
    }
}
