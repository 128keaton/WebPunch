//
//  PunchHistoryViewController.swift
//  WebPunch
//
//  Created by Keaton Burleson on 4/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit
import AudioToolbox

class PunchHistoryViewController: UITableViewController {
    enum DisplayMode {
        case punchesByPeriods
        case punchesByWeek
        case punchesByDay
    }

    // MARK: - Properties
    let punchModel: PunchModel = PunchModel.sharedInstance
    let punchHistorySoundURL = URL(string: "/System/Library/Audio/UISounds/acknowledgment_received.caf")
    let payPeriodHistorySoundURL = URL(string: "/System/Library/Audio/UISounds/acknowledgment_sent.caf")

    var punchHistorySoundID: SystemSoundID? = nil
    var payPeriodHistoryID: SystemSoundID? = nil
    var dayPayPeriods: [DayPayPeriod] = []
    var weekPayPeriods: [WeekPayPeriod] = []
    var fullPayPeriods: [FullPayPeriod] = []
    var noDataView: UILabel? = nil
    var showTaxedIncome = true
    var switchLabel: UILabel!
    var customView: UIView!
    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!
    var pullDownInProgress = false

    var displayMode: DisplayMode = .punchesByDay {
        didSet {
            displayModeChanged()
        }
    }

    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }

    @IBAction func backButtonPressed(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    @objc func switchMode() {
        self.switchLabel.text = ""

        UIView.animate(withDuration: 0.3) {
            self.switchLabel.alpha = 0.0
        }

        if displayMode == .punchesByDay {
            displayMode = .punchesByWeek
        } else if displayMode == .punchesByWeek {
            displayMode = .punchesByPeriods
        } else {
            displayMode = .punchesByDay
        }
    }

    @IBAction func refresh() {
        punchModel.refresh()
    }

    override func viewDidLoad() {
        self.tableView.tableFooterView = UIView(frame: CGRect.zero)
        self.becomeFirstResponder()

        createNoDataView()
        setupModel()
        addRefreshControl()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake && displayMode == .punchesByPeriods {
            showTaxedIncome = !showTaxedIncome
            self.tableView.reloadData()
        }
    }

    private func displayModeChanged() {
        playSoundForTransition()

        DispatchQueue.main.async {
            self.tableView.reloadData()
        }

        switch self.displayMode {
        case .punchesByDay:
            self.navigationItem.prompt = "(by day)"
            break
        case .punchesByWeek:
            self.navigationItem.prompt = "(by week)"
            break
        case .punchesByPeriods:
            self.navigationItem.prompt = "(by period)"
            break
        }
    }

    private func playSoundForTransition() {
        if let soundID = punchHistorySoundID {
            AudioServicesPlaySystemSound(soundID);
        } else {
            var newSoundID = SystemSoundID()
            AudioServicesCreateSystemSoundID(punchHistorySoundURL! as CFURL, &newSoundID)
            AudioServicesPlaySystemSound(newSoundID);
            punchHistorySoundID = newSoundID
        }
    }

    private func loadCustomRefreshContents() {
        let refreshContents = Bundle.main.loadNibNamed("RefreshContents", owner: self, options: nil)
        customView = refreshContents![0] as? UIView
        customView.frame = refreshControl!.bounds
        customView.backgroundColor = self.navigationController?.navigationBar.barTintColor

        self.refreshControl?.tintColor = .clear

        if let label = (customView.subviews.first { type(of: $0) == UILabel.self }) {
            self.switchLabel = label as? UILabel
        }

        switchLabel.text = "Switch to Week View"
        refreshControl!.addSubview(customView)
    }

    private func createNoDataView() {
        if noDataView == nil {
            noDataView = UILabel(frame: self.tableView.frame)
            noDataView?.textAlignment = .center
            noDataView?.textColor = UIColor.darkGray
            noDataView?.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
            noDataView?.text = "No recorded punches"
        }
    }

    private func setupModel() {
        punchModel.delegate = self
        punchModel.refresh()
    }

    private func addRefreshControl() {
        refreshControl = UIRefreshControl()
        loadCustomRefreshContents()
    }

    override func viewDidAppear(_ animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if self.weekPayPeriods.count == 0 {
                self.tableView.backgroundView = self.noDataView!
            }
        }
    }

    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        pullDownInProgress = scrollView.contentOffset.y <= 0.0
        switch self.displayMode {
        case .punchesByDay:
            self.switchLabel.text = "Switch to Week View"
            break
        case .punchesByWeek:
            self.switchLabel.text = "Switch to Period View"
            break
        case .punchesByPeriods:
            self.switchLabel.text = "Switch to Day View"
            break
        }
    }

    func finishPullDown(){
        pullDownInProgress = false
        UIView.animate(withDuration: 0.3) {
            self.tableView.subviews.forEach {
                $0.layer.transform = CATransform3DIdentity
            }
            self.switchLabel.alpha = 0.0
        }
        self.switchMode()
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let scrollViewContentOffsetY = scrollView.contentOffset.y

        if pullDownInProgress && scrollView.contentOffset.y <= 0.0 {
            switchLabel.alpha = abs(scrollViewContentOffsetY / 350.0)
            var transform = CATransform3DIdentity;
            transform.m34 = 1.0 / 1000.0;
            transform = CATransform3DRotate(transform, abs(scrollViewContentOffsetY / 400.0), 0.2, 0, 0)
            self.tableView.visibleCells.forEach {
                $0.layer.transform = transform
            }
            if abs(scrollViewContentOffsetY) > 315.0 {
                self.finishPullDown()
            }
        } else {
            pullDownInProgress = false
        }
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.alpha = 0

        UIView.animate(
            withDuration: 0.3,
            delay: 0.003 * Double(indexPath.row),
            animations: {
                cell.alpha = 1
            })
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 108.0
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if self.displayMode == .punchesByPeriods && self.fullPayPeriods[section].incomplete {
            return "CURRENT PERIOD"
        }
        return nil
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        if displayMode == .punchesByWeek {
            return self.weekPayPeriods.count
        } else if displayMode == .punchesByDay {
            return self.dayPayPeriods.count
        } else {
            return self.fullPayPeriods.count
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if displayMode == .punchesByWeek {
            return self.weekPayPeriods[section].punches.count
        } else if displayMode == .punchesByDay {
            return self.dayPayPeriods[section].punches.count
        } else {
            return self.fullPayPeriods[section].weekPayPeriods.count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if displayMode == .punchesByWeek {
            let payPeriod = self.weekPayPeriods[section]
            return "\(payPeriod.amountWorked.readableUnit) total. \(payPeriod)"
        } else if displayMode == .punchesByDay {
            let payPeriod = self.dayPayPeriods[section]
            return "\(payPeriod.amountWorked.readableUnit) total. \(payPeriod)"
        } else {
            let payPeriod = self.fullPayPeriods[section]
            return "\(payPeriod.amountWorked.readableUnit) total. \(payPeriod)"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell()
        var punch: Punch? = nil

        if displayMode == .punchesByWeek {
            punch = self.weekPayPeriods[indexPath.section].punches[indexPath.row]
        } else if displayMode == .punchesByDay {
            punch = self.dayPayPeriods[indexPath.section].punches[indexPath.row]
        } else if displayMode == .punchesByPeriods {
            cell = tableView.dequeueReusableCell(withIdentifier: "PayPeriodCell", for: indexPath)
        }

        if let punch = punch {
            if punch.punchType == "In" {
                cell = tableView.dequeueReusableCell(withIdentifier: "PunchInCell", for: indexPath)
            } else if punch.punchType == "Out" {
                cell = tableView.dequeueReusableCell(withIdentifier: "PunchOutCell", for: indexPath)
            }
        }

        if let punchCell = cell as? PunchInCell,
            let punch = punch {
            punchCell.punchTimeLabel?.text = punch.punchTime
            punchCell.punchDateLabel?.text = punch.punchDate
        }

        if let punchCell = cell as? PunchOutCell,
            let punch = punch {
            punchCell.punchTimeLabel?.text = punch.punchTime
            punchCell.punchDateLabel?.text = punch.punchDate
        }

        if let periodCell = cell as? PayPeriodCell {
            let fullPayPeriod = self.fullPayPeriods[indexPath.section].weekPayPeriods[indexPath.row]
            periodCell.periodIsCurrent = fullPayPeriod.incomplete
            periodCell.rangeLabel?.text = fullPayPeriod.description
            periodCell.amountOfTimeLabel?.text = fullPayPeriod.amountWorked.readableUnit
            periodCell.punchesAmount?.text = "\(fullPayPeriod.punches.count)"

            if let payString = Defaults.object(forKey: "hourlyPay") as? String,
                let payDouble = Double(payString),
                let taxRateString = Defaults.object(forKey: "taxRate") as? String,
                let taxRateDouble = Double(taxRateString),
                fullPayPeriod.amountWorked.hours > 0 {

                let formatter = NumberFormatter()
                formatter.locale = Locale.current
                formatter.numberStyle = .currency

                let amountPreTax = payDouble * Double(fullPayPeriod.amountWorked.hours)
                let amountTaxed = amountPreTax - (amountPreTax * taxRateDouble)

                if showTaxedIncome {
                    periodCell.earnedAmountLabel?.text = formatter.string(from: amountTaxed as NSNumber)
                } else {
                    periodCell.earnedAmountLabel?.text = formatter.string(from: amountPreTax as NSNumber)
                }
            } else {
                periodCell.earnedAmountLabel?.text = "$0.00"
            }

        }

        cell.isUserInteractionEnabled = false

        return cell
    }
}

// MARK: - ModelDelegate
extension PunchHistoryViewController: PunchModelDelegate {

    func modelBeginningUpdates() {
        refreshControl?.endRefreshing()
    }

    func modelEndingUpdates() {
        self.dayPayPeriods = PunchModel.sharedInstance.dayPayPeriods.filter { $0.amountWorked.hasHours || $0.amountWorked.hasMinutes }
        self.weekPayPeriods = PunchModel.sharedInstance.weekPayPeriods.filter { $0.amountWorked.hasHours || $0.amountWorked.hasMinutes }
        self.fullPayPeriods = PunchModel.sharedInstance.fullPayPeriods.filter { $0.amountWorked.hasHours || $0.amountWorked.hasMinutes }

        tableView.reloadData()
    }

    func errorUpdating(_ error: Error) {
        let message = error.localizedDescription
        let alertController = UIAlertController(title: "iCloud Error", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
}

