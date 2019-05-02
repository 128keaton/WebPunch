//
//  FoundationExtensions.swift
//  WebPunch
//
//  Created by Keaton Burleson on 4/22/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation

extension IndexSet {
    func difference(from other: IndexSet) -> IndexSet {
        let thisSet = Set(self)
        let otherSet = Set(other)
        return IndexSet(thisSet.symmetricDifference(otherSet))
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension Date {
    public var twoWeeksAhead: Date {
        var dateComponents = DateComponents()
        dateComponents.day = 14

        return Calendar.current.date(byAdding: dateComponents, to: self)!
    }

    public var oneWeekAhead: Date {
        var dateComponents = DateComponents()
        dateComponents.day = 7

        return Calendar.current.date(byAdding: dateComponents, to: self)!
    }

    public var firstDateofWeekFromSelf: Date {
        var dateComponents = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        dateComponents.weekday = 1
        return Calendar.current.date(from: dateComponents)!
    }
}

extension URL {
    func valueOf(_ queryParamaterName: String) -> String? {
        guard let url = URLComponents(string: self.absoluteString) else { return nil }
        return url.queryItems?.first(where: { $0.name == queryParamaterName })?.value
    }
}

extension TimeInterval {
    public var milliseconds: Int {
        return Int((truncatingRemainder(dividingBy: 1)) * 1000)
    }

    public var seconds: Int {
        return Int(self) % 60
    }

    public var minutes: Int {
        return (Int(self) / 60) % 60
    }

    public var hours: Int {
        return Int(self) / 3600
    }

    private var hourUnit: String {
        if hours > 1 {
            return "hours"
        }
        return "hour"
    }

    private var minuteUnit: String {
        if minutes > 1 {
            return "minutes"
        }
        return "minute"
    }

    private var secondUnit: String {
        if seconds > 1 {
            return "seconds"
        }
        return "second"
    }

    private var millisecondUnit: String {
        return "milliseconds"
    }

    public var hasMinutes: Bool {
        return self.minutes != 0
    }

    public var hasHours: Bool {
        return self.hours != 0
    }

    public var shouldDisplay: Bool {
        return (hasMinutes && hasHours)
    }

    public var readableUnit: String {
        if hours != 0 {
            if minutes != 0 {
                return "\(hours) \(hourUnit) \(minutes) \(minuteUnit)"
            }
            return "\(hours) \(hourUnit)"
        } else if minutes != 0 {
            return "\(minutes) \(minuteUnit)"
        } else if seconds != 0 {
            return "\(seconds) \(secondUnit)"
        } else {
            return "\(milliseconds) \(millisecondUnit)"
        }
    }
}