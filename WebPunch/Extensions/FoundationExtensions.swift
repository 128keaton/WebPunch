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
    
    public var stripTime: Date{
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: self)
      
        dateComponents.hour = 0
        dateComponents.minute = 0
        dateComponents.second = 0
        dateComponents.nanosecond = 0
        
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

    func format(using units: NSCalendar.Unit = [.hour, .minute]) -> String {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.minute]

        if self >= 3600 {
            formatter.allowedUnits.insert(.hour)
        } else if self <= 60 {
            formatter.allowedUnits.insert(.second)
        }

        return formatter.string(from: self)!
    }

    func getHours() -> Double {
        return self / 3600.0
    }
    
    func getMinutes() -> Double {
        return (self / 60).truncatingRemainder(dividingBy: 60)
    }
}

extension String {
    static func random(length: Int = 12) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
}
