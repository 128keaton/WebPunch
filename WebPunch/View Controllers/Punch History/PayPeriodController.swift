//
//  PayPeriodController.swift
//  WebPunch
//
//  Created by Keaton Burleson on 5/2/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit
import AudioToolbox

class PayPeriodController: UITableViewController {
    // MARK: - Properties
    let punchModel: PunchModel = PunchModel.sharedInstance

    var fullPayPeriods: [FullPayPeriod] = []
    var noDataView: UILabel? = nil
    var showTaxedIncome = true
    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!

    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }

    @IBAction func backButtonPressed(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func refresh() {
        punchModel.refresh()
    }

    override func viewDidLoad() {
        self.tableView.tableFooterView = UIView(frame: CGRect.zero)
        self.becomeFirstResponder()

        createNoDataView()
        setupModel()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        showTaxedIncome = !showTaxedIncome
        self.tableView.reloadData()

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

    override func viewDidAppear(_ animated: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if self.fullPayPeriods.count == 0 {
                self.tableView.backgroundView = self.noDataView!
            }
        }
        punchModel.delegate = self
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
        if self.fullPayPeriods[section].incomplete {
            return "CURRENT PERIOD"
        }
        return nil
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.fullPayPeriods.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.fullPayPeriods[section].weekPayPeriods.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let payPeriod = self.fullPayPeriods[section]
        return "\(payPeriod.amountWorked.readableUnit) total. \(payPeriod)"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell()
        cell = tableView.dequeueReusableCell(withIdentifier: "PayPeriodCell", for: indexPath)

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
extension PayPeriodController: PunchModelDelegate {

    func modelBeginningUpdates() {
        print("Refreshing table view shortly")
    }

    func modelEndingUpdates() {
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

