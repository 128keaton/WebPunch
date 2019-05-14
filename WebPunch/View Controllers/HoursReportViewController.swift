//
//  HoursReportViewController.swift
//  WebPunch
//
//  Created by Keaton Burleson on 5/14/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit
import UICountingLabel

class HoursReportViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var hoursLabel: UICountingLabel!
    @IBOutlet weak var weekLabel: UILabel!
    @IBOutlet weak var earnedLabel: UICountingLabel!

    // MARK: - Properties
    let punchModel: PunchModel = PunchModel.sharedInstance
    let calendar = NSCalendar.current
    let selectedWeek = Date()

    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!

    var hoursForSelectedWeek: TimeInterval {
        var hours = 0.0

        getPunchesForWeekOf(selectedWeek).forEach {
            hours += punchModel.getHoursForSet($0)
        }

        return hours
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        hoursLabel.alpha = 0.0
        weekLabel.alpha = 0.0
        earnedLabel.alpha = 0.0
        
        earnedLabel.animationDuration = 1.5
        hoursLabel.animationDuration = 1.5
        
        earnedLabel.method = .easeOut
        hoursLabel.method = .easeOut

        NotificationCenter.default.addObserver(self, selector: #selector(modelEndingUpdates), name: PunchModel.modelUpdatesEnding, object: nil)
        punchModel.refresh()
    }

    private func getPunchesForWeekOf(_ date: Date? = nil) -> [[String: Punch?]] {
        let punchSets = punchModel.punchesInSets()
        var weekDate = Date().firstDateofWeekFromSelf

        if let validDate = date {
            weekDate = validDate.firstDateofWeekFromSelf
        }

        return punchSets.filter {
            if let punchIn = $0["in"] as? Punch {
                return punchIn.createdAt.firstDateofWeekFromSelf == weekDate
            }
            return false
        }
    }

    private func updateView() {
        var showEarned = false
        var earnedAmount = 0.0
        
        if hoursForSelectedWeek > 0.0 {
            hoursLabel.text = "0 Hours"
        } else {
            showEarned = false
            hoursLabel.text = "No hours worked"
        }

        if let payString = Defaults.object(forKey: "hourlyPay") as? String,
            let payDouble = Double(payString),
            let taxRateString = Defaults.object(forKey: "taxRate") as? String,
            let taxRateDouble = Double(taxRateString),
            hoursForSelectedWeek > 0.0 {
            let amountPreTax = payDouble * hoursForSelectedWeek
            let amountTaxed = amountPreTax - (amountPreTax * taxRateDouble)
            
            showEarned = true
            earnedLabel.text = "$0.00 Earned"
            earnedAmount = amountTaxed
        }
        
        weekLabel.text = "This Week"
        
        UIView.animate(withDuration: 0.3, animations: {
            if showEarned {
                self.earnedLabel.alpha = 1.0
            }
            
            self.hoursLabel.alpha = 1.0
            self.weekLabel.alpha = 1.0
        }) { (didComplete) in
            if didComplete{
                DispatchQueue.main.async {
                    if self.hoursForSelectedWeek > 0.0 {
                        self.hoursLabel.formatBlock = { value in
                            String(format: "%.02f Hours", value)
                        }
                        self.hoursLabel.countFromZero(to: CGFloat(self.hoursForSelectedWeek))
                    }
                    
                    if showEarned {
                        self.earnedLabel.formatBlock = { value in
                            String(format: "~$%.02f Earned", value)
                        }
                        self.earnedLabel.countFromZero(to: CGFloat(earnedAmount))
                    }
                }
            }
        }
    }

    @objc func modelEndingUpdates() {
        DispatchQueue.main.async {
            self.updateView()
        }
    }

    @IBAction func backButtonPressed(_ sender: UIBarButtonItem) {
        self.tabBarController?.dismiss(animated: true, completion: nil)
    }

    @IBAction func refresh() {
        punchModel.refresh()
    }

}
