//
//  PayPeriods.swift
//  WebPunch
//
//  Created by Keaton Burleson on 4/22/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

class WeekPayPeriod: CustomStringConvertible, Equatable {
    var punches: [Punch] = []
    var weekOf: Date
    var incomplete: Bool {
        return self.weekOf.oneWeekAhead > Date()
    }

    init(punches: [Punch], weekOf: Date) {
        self.punches = punches
        self.weekOf = weekOf
    }

    init(weekOf: Date) {
        self.weekOf = weekOf
    }

    init(punch: Punch, weekOf: Date) {
        self.punches = [punch]
        self.weekOf = weekOf
    }

    public func addPunch(newPunch punch: Punch) {
        self.punches.append(punch)
    }

    public var amountWorked: TimeInterval {
        var totalHours = 0.0

        let punchesOut = sortPunches((punches.filter { $0.getPunchType() == .Out }))

        for (index, inPunch) in (punches.filter { $0.getPunchType() == .In }).enumerated() {
            if punchesOut.indices.contains(index) {
                let outPunch = punchesOut[index]
                print(inPunch)
                print(outPunch)
                print("\n")
                totalHours += fabs(inPunch.createdAt.timeIntervalSince(outPunch.createdAt))
            } else {
                print(inPunch)
                print("\n")
                totalHours += fabs(inPunch.createdAt.timeIntervalSinceNow)
            }
        }

        return totalHours
    }

    private func sortPunches(_ newPunches: [Punch]) -> [Punch] {
        return newPunches.sorted(by: { $0.createdAt.compare($1.createdAt) == .orderedDescending })
    }

    public var description: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"

        if self.incomplete {
            return "\(formatter.string(from: self.weekOf)) - (now)"
        } else {
            return "\(formatter.string(from: self.weekOf)) - \(formatter.string(from: self.weekOf.oneWeekAhead))"
        }
    }

    static func == (lhs: WeekPayPeriod, rhs: WeekPayPeriod) -> Bool {
        return lhs.punches == rhs.punches && lhs.weekOf == rhs.weekOf && lhs.incomplete == rhs.incomplete
    }
}

class DayPayPeriod: CustomStringConvertible, Equatable {
    var day: Date
    var punches: [Punch] = []

    init(punches: [Punch], day: Date) {
        self.punches = punches
        self.day = day
    }

    init(punch: Punch, day: Date) {
        self.punches = [punch]
        self.day = day
    }

    public func addPunch(newPunch punch: Punch) {
        self.punches.append(punch)
    }

    public var amountWorked: TimeInterval {
        var totalHours = 0.0

        let punchesOut = sortPunches((punches.filter { $0.getPunchType() == .Out }))

        for (index, inPunch) in (punches.filter { $0.getPunchType() == .In }).enumerated() {
            if punchesOut.indices.contains(index) {
                let outPunch = punchesOut[index]
                print(inPunch)
                print(outPunch)
                print("\n")
                totalHours += fabs(inPunch.createdAt.timeIntervalSince(outPunch.createdAt))
            } else {
                print(inPunch)
                print("\n")
                totalHours += fabs(inPunch.createdAt.timeIntervalSinceNow)
            }
        }

        return totalHours
    }

    public var description: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: self.day)
    }

    private func sortPunches(_ newPunches: [Punch]) -> [Punch] {
        return newPunches.sorted(by: { $0.createdAt.compare($1.createdAt) == .orderedDescending })
    }

    static func == (lhs: DayPayPeriod, rhs: DayPayPeriod) -> Bool {
        return lhs.punches == rhs.punches && lhs.day == rhs.day
    }
}

class FullPayPeriod: CustomStringConvertible {
    var weekPayPeriods: [WeekPayPeriod] = []

    var weekOf: Date {
        return self.weekPayPeriods.first!.weekOf
    }
    var amountWorked: TimeInterval {
        return (weekPayPeriods.compactMap { $0.amountWorked }).reduce(0, +)
    }
    var incomplete: Bool {
        return self.weekPayPeriods.count == 1 || self.weekOf.twoWeeksAhead > Date()
    }

    init(firstWeek: WeekPayPeriod, secondWeek: WeekPayPeriod) {
        self.weekPayPeriods = [firstWeek, secondWeek]
    }

    public var description: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"

        if self.incomplete {
            return "\(formatter.string(from: self.weekOf)) - (now)"
        } else {
            return "\(formatter.string(from: self.weekOf)) - \(formatter.string(from: self.weekOf.twoWeeksAhead))"
        }
    }

    init(bothWeeks weeks: [WeekPayPeriod]) {
        if weeks.count <= 2 && weeks.count < 3 && weeks.count > 0 {
            self.weekPayPeriods = weeks
        } else {
            fatalError("A FullPayPeriod cannot have more than two weeks, or less than one")
        }
    }
}
