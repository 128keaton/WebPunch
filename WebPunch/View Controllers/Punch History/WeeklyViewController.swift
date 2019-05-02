//
//  WeeklyViewController.swift
//  WebPunch
//
//  Created by Keaton Burleson on 5/1/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit
import AudioToolbox

class WeeklyViewController: UITableViewController {
    // MARK: - Properties
    let punchModel: PunchModel = PunchModel.sharedInstance
    
    var weekPayPeriods: [WeekPayPeriod] = []
    var noDataView: UILabel? = nil
    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!
    
    override var canBecomeFirstResponder: Bool {
        get {
            return true
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
            if self.weekPayPeriods.count == 0 {
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
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.weekPayPeriods.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.weekPayPeriods[section].punches.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let payPeriod = self.weekPayPeriods[section]
        return "\(payPeriod.amountWorked.readableUnit) total. \(payPeriod)"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell()
        var punch: Punch? = nil
        
        punch = self.weekPayPeriods[indexPath.section].punches[indexPath.row]
        
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
        
        cell.isUserInteractionEnabled = false
        
        return cell
    }
}

// MARK: - ModelDelegate
extension WeeklyViewController: PunchModelDelegate {
    
    func modelBeginningUpdates() {
        print("Refreshing table view shortly")
    }
    
    func modelEndingUpdates() {
        self.weekPayPeriods = PunchModel.sharedInstance.weekPayPeriods.filter { $0.amountWorked.hasHours || $0.amountWorked.hasMinutes }
        tableView.reloadData()
    }
    
    func errorUpdating(_ error: Error) {
        let message = error.localizedDescription
        let alertController = UIAlertController(title: "iCloud Error", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
}