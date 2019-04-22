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
        let punchesIn = (punches.filter { $0.getPunchType() == .In })
        let punchesOut = (punches.filter { $0.getPunchType() == .Out })
        var loosePunches = [Punch]()

        for (index, punchedIn) in punchesIn.enumerated() {
            if punchesOut.indices.contains(index) {
                let punchedOut = punchesOut[index]
                totalHours += punchedOut.createdAt.timeIntervalSince(punchedIn.createdAt)
            } else {
                loosePunches.append(punchedIn)
            }
        }

        return totalHours
    }

    public var description: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"

        if self.incomplete {
            return "\(formatter.string(from: self.weekOf)) - (current)"
        } else {
            return "\(formatter.string(from: self.weekOf)) - \(formatter.string(from: self.weekOf.oneWeekAhead))"
        }
    }

    static func == (lhs: WeekPayPeriod, rhs: WeekPayPeriod) -> Bool {
        return lhs.punches == rhs.punches && lhs.weekOf == rhs.weekOf && lhs.incomplete == rhs.incomplete
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
            return "\(formatter.string(from: self.weekOf)) - (current)"
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
