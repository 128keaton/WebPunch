//
//  PunchHistoryViewController.swift
//  WebPunch
//
//  Created by Keaton Burleson on 4/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit
class PunchHistoryViewController: UITableViewController {
    enum DisplayMode {
        case punches
        case payPeriods
    }

    // MARK: - Properties
    let punchModel: PunchModel = PunchModel.sharedInstance

    var punchesFromPayPeriods: [WeekPayPeriod] = []
    var payPeriods: [FullPayPeriod] = []
    var noDataView: UILabel? = nil

    var displayMode: DisplayMode = .punches {
        didSet {
            displayModeChanged()
        }
    }

    @IBAction func backButtonPressed(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func switchModeButtonPressed(_ sender: UIBarButtonItem) {
        if displayMode == .payPeriods {
            displayMode = .punches
        } else {
            displayMode = .payPeriods
        }
    }

    override func viewDidLoad() {
        self.tableView.tableFooterView = UIView(frame: CGRect.zero)

        createNoDataView()
        setupModel()
        addRefreshControl()
    }

    private func displayModeChanged() {
        let transitionOptions: UIView.AnimationOptions = [.transitionFlipFromRight, .showHideTransitionViews]

        UIView.transition(with: self.view, duration: 0.3, options: transitionOptions, animations: {
            DispatchQueue.main.async {
                self.title = self.displayMode == .punches ? "Punch History" : "Pay Periods"
                self.tableView.reloadData()
            }
        })
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
        refreshControl?.addTarget(punchModel, action: #selector(PunchModel.refresh), for: .valueChanged)
    }

    override func viewDidAppear(_ animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if self.punchesFromPayPeriods.count == 0 {
                self.tableView.backgroundView = self.noDataView!
            }
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 108.0
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if displayMode == .punches {
            let payPeriod = self.punchesFromPayPeriods[indexPath.section]
            self.displayAlert(bodyText: "You have worked \(payPeriod.amountWorked.readableUnit) between \(payPeriod)", title: "Week Total")
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        if displayMode == .punches {
            return self.punchesFromPayPeriods.count
        } else {
            return self.payPeriods.count
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if displayMode == .punches {
            return self.punchesFromPayPeriods[section].punches.count
        } else {
            return self.payPeriods[section].weekPayPeriods.count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if displayMode == .punches {
            let payPeriod = self.punchesFromPayPeriods[section]
            return "\(payPeriod.amountWorked.readableUnit) total. \(payPeriod)"
        } else {
            let payPeriod = self.payPeriods[section]
            return "\(payPeriod.amountWorked.readableUnit) total. \(payPeriod)"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell()

        if displayMode == .punches {
            let punch = self.punchesFromPayPeriods[indexPath.section].punches[indexPath.row]
            if punch.punchType == "In" {
                cell = tableView.dequeueReusableCell(withIdentifier: "PunchInCell", for: indexPath)
            } else if punch.punchType == "Out" {
                cell = tableView.dequeueReusableCell(withIdentifier: "PunchOutCell", for: indexPath)
            }
        } else if displayMode == .payPeriods {
            cell = tableView.dequeueReusableCell(withIdentifier: "PayPeriodCell", for: indexPath)
        }

        if let punchCell = cell as? PunchCell {
            let punch = self.punchesFromPayPeriods[indexPath.section].punches[indexPath.row]
            punchCell.punchTypeLabel?.text = punch.punchType
            punchCell.punchTimeLabel?.text = punch.punchTime
            punchCell.punchDateLabel?.text = punch.punchDate
        }

        if let punchCell = cell as? PunchInCell {
            let punch = self.punchesFromPayPeriods[indexPath.section].punches[indexPath.row]
            punchCell.punchTypeLabel?.text = punch.punchType
            punchCell.punchTimeLabel?.text = punch.punchTime
            punchCell.punchDateLabel?.text = punch.punchDate
        }

        if let punchCell = cell as? PunchOutCell {
            let punch = self.punchesFromPayPeriods[indexPath.section].punches[indexPath.row]
            punchCell.punchTypeLabel?.text = punch.punchType
            punchCell.punchTimeLabel?.text = punch.punchTime
            punchCell.punchDateLabel?.text = punch.punchDate
        }

        if let periodCell = cell as? PayPeriodCell {
            let payPeriod = self.payPeriods[indexPath.section].weekPayPeriods[indexPath.row]
            print(payPeriod.description)
            periodCell.isUserInteractionEnabled = false
            periodCell.periodIsCurrent = payPeriod.incomplete
            periodCell.rangeLabel?.text = payPeriod.description
            periodCell.amountOfTimeLabel?.text = payPeriod.amountWorked.readableUnit
        }

        return cell
    }
}

// MARK: - ModelDelegate
extension PunchHistoryViewController: PunchModelDelegate {

    func modelBeginningUpdates() {
        refreshControl?.endRefreshing()
    }

    func modelEndingUpdates() {
        self.punchesFromPayPeriods = PunchModel.sharedInstance.payPeriods.filter { $0.amountWorked.hasHours || $0.amountWorked.hasMinutes }
        self.payPeriods = []
        
        PunchModel.sharedInstance.payPeriods.chunked(into: 2).forEach {
            if ($0.count <= 2) {
                self.payPeriods.append(FullPayPeriod(bothWeeks: $0))
            }
        }

        tableView.reloadData()
    }

    func errorUpdating(_ error: Error) {
        let message = error.localizedDescription
        let alertController = UIAlertController(title: "iCloud Error", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
}

