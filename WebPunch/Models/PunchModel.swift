//
//  PunchModel.swift
//  WebPunch
//
//  Created by Keaton Burleson on 5/14/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//


import Foundation
import CloudKit
import CoreLocation

class PunchModel {
    static let sharedInstance = PunchModel()

    static let refreshModel = Notification.Name("punchModelRefresh")
    static let modelEndUpdates = Notification.Name("punchModelEndUpdates")
    static let modelBeginUpdates = Notification.Name("punchModelBeginUpdates")

    private let database = CKContainer.default().privateCloudDatabase

    var onChange: (() -> Void)?
    var onError: ((Error) -> Void)?
    var notificationQueue = OperationQueue.main


    var punchInRecords = [CKRecord]()
    var punchOutRecords = [CKRecord]()

    var insertedPunchInObjects = [PunchIn]()
    var insertedPunchOutObjects = [PunchOut]()

    var deletedPunchInObjectIds = Set<CKRecord.ID>()
    var deletedPunchOutObjectIds = Set<CKRecord.ID>()

    private (set) public var lastPunch: Punch? = nil

    var punchesIn = [PunchIn]() {
        didSet {
            self.notificationQueue.addOperation {
                self.onChange?()
            }
        }
    }

    var punchesOut = [PunchOut]() {
        didSet {
            self.notificationQueue.addOperation {
                self.onChange?()
            }
        }
    }

    var allPunches: [OperationalPunch] {
        var _allPunches: [OperationalPunch] = []

        _allPunches.append(contentsOf: (punchesOut.map { OperationalPunch($0) }))
        _allPunches.append(contentsOf: ( punchesIn.map { OperationalPunch($0) }))

        return _allPunches.sorted()
    }

    var datesWithPunches: Set<Date> {
        return Set(allPunches.map { $0.at.stripTime })
    }

    var matchedPunches: [MatchedPunches] {
        return datesWithPunches.map { date in
            MatchedPunches(punches: allPunches.filter { punch in
                punch.isSameDay(date)
            }, key: date)
        }
    }

    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(refreshPunches), name: PunchModel.refreshModel, object: nil)
    }

    private func handle(error: Error) {
        self.notificationQueue.addOperation {
            self.onError?(error)
        }
    }

    public func didPunchOut() {
        if var lastPunchIn = self.lastPunch as? PunchIn {
            var punchOut = PunchOut()

            punchOut.punchIn = lastPunchIn
            lastPunchIn.punchOut = punchOut

            let saveOperation = CKModifyRecordsOperation(recordsToSave: [punchOut.record, lastPunchIn.record], recordIDsToDelete: nil)

            saveOperation.perRecordCompletionBlock = { record, error in
                guard error == nil else {
                    self.handle(error: error!)
                    return
                }
            }

            saveOperation.completionBlock = {
                print(punchOut)

                self.lastPunch = nil

                self.insertedPunchOutObjects.append(punchOut)

                self.insertedPunchInObjects.removeAll { $0.id == lastPunchIn.id }
                self.insertedPunchInObjects.append(lastPunchIn)

                self.updatePunches()
            }

            database.add(saveOperation)
        }
    }

    public func didPunchIn() {
        let punchIn = PunchIn()
        database.save(punchIn.record) { _, error in
            guard error == nil else {
                self.handle(error: error!)
                return
            }
        }

        print(punchIn)

        self.lastPunch = punchIn
        self.insertedPunchInObjects.append(punchIn)
        updatePunches()
    }

    public func updatePunch(_ punch: Punch, completion: @escaping (Bool) -> ()) {
        database.save(punch.record) { _, error in
            guard error == nil else {
                self.handle(error: error!)
                return completion(false)
            }
        }

        print("Saved punch")
        refreshPunches()
        completion(true)
    }

    public func getOppositePunch(_ aPunch: Punch, completion: @escaping (Punch?) -> ()) {
        if let punch = aPunch as Any as? Punch,
            let contrastingRecordID = punch.contrastingRecordID {
            database.fetch(withRecordID: contrastingRecordID) { (record, error) in
                guard let record = record, error == nil else {
                    self.handle(error: error!)
                    return completion(nil)
                }
                if type(of: punch) == PunchIn.self {
                    completion(PunchOut(record: record))
                }
                completion(PunchIn(record: record))
            }
        }
    }

    private func updatePunches() {
        print("Updating punches...")
        NotificationCenter.default.post(name: PunchModel.modelBeginUpdates, object: self.matchedPunches)
        
        var knownPunchesInIds = Set(punchInRecords.map { $0.recordID })
        var knownPunchesOutIds = Set(punchOutRecords.map { $0.recordID })

        // remove objects from our local list once we see them returned from the cloudkit storage
        self.insertedPunchInObjects.removeAll { punch in
            knownPunchesInIds.contains(punch.record.recordID)
        }

        self.insertedPunchOutObjects.removeAll { punch in
            knownPunchesOutIds.contains(punch.record.recordID)
        }

        knownPunchesInIds.formUnion(self.insertedPunchInObjects.map { $0.record.recordID })
        knownPunchesOutIds.formUnion(self.insertedPunchOutObjects.map { $0.record.recordID })

        // remove objects from our local list once we see them not being returned from storage anymore
        self.deletedPunchInObjectIds.formIntersection(knownPunchesInIds)
        self.deletedPunchOutObjectIds.formIntersection(knownPunchesOutIds)

        var punchesIn = punchInRecords.map { record in PunchIn(record: record) }
        var punchesOut = punchOutRecords.map { record in PunchOut(record: record) }

        punchesIn.append(contentsOf: self.insertedPunchInObjects)
        punchesOut.append(contentsOf: self.insertedPunchOutObjects)

        punchesIn.removeAll { punch in deletedPunchInObjectIds.contains(punch.record.recordID) }
        punchesOut.removeAll { punch in deletedPunchOutObjectIds.contains(punch.record.recordID) }

        self.punchesOut = punchesOut.sorted()
        self.punchesIn = punchesIn.sorted()

        print("Finished updating punches!")
        NotificationCenter.default.post(name: PunchModel.modelEndUpdates, object: self.matchedPunches)
    }

    @objc func refreshPunches() {
        let inQuery = CKQuery(recordType: PunchIn.recordType, predicate: NSPredicate(value: true))
        let outQuery = CKQuery(recordType: PunchOut.recordType, predicate: NSPredicate(value: true))

        database.perform(inQuery, inZoneWith: nil) { punchInRecords, error in
            guard let punchInRecords = punchInRecords, error == nil else {
                self.handle(error: error!)
                return
            }
            self.punchInRecords = punchInRecords

            self.database.perform(outQuery, inZoneWith: nil) { punchOutRecords, error in
                guard let punchOutRecords = punchOutRecords, error == nil else {
                    self.handle(error: error!)
                    return
                }

                self.punchOutRecords = punchOutRecords
                self.updatePunches()
            }
        }
    }

    func getHoursForCurrentPunches(ofWeek aDate: Date = Date()) -> TimeInterval {
        return getHoursForPunches(self.punchesIn, ofWeek: aDate)
    }

    func getHoursForPunches(_ punches: [PunchIn], ofWeek aDate: Date = Date()) -> TimeInterval {
        let weekDate = aDate.firstDateofWeekFromSelf

        var totalHours = 0.0

        let filteredPunches = punches.filter { $0.at.firstDateofWeekFromSelf == weekDate }

        filteredPunches.forEach { punchIn in
            totalHours += punchIn.totalWorked
        }

        return totalHours
    }

}
