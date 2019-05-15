//
//  PunchHistoryViewController.swift
//  WebPunch
//
//  Created by Keaton Burleson on 5/14/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit
import Differ

class PunchHistoryViewController: UITableViewController {
    let punchModel: PunchModel = PunchModel.sharedInstance

    var noDataView: UILabel? = nil
    var currentPunches: [OperationalPunch] = []
    var currentSections: [Date] {
        return Array(Set(currentPunches.map { punch in
            return punch.at.stripTime
        }))
    }

    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableFooterView = UIView(frame: CGRect.zero)

        becomeFirstResponder()
        createNoDataView()

        NotificationCenter.default.addObserver(self, selector: #selector(modelUpdated), name: PunchModel.modelUpdated, object: nil)
        punchModel.refreshPunches()

        view.layoutIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if self.punchModel.datesWithPunches.count == 0 {
                self.tableView.backgroundView = self.noDataView!
            }
        }
    }


    override func numberOfSections(in tableView: UITableView) -> Int {
        return currentSections.count
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

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (currentPunches.filter { punch in
            punch.isSameDay(currentSections[section])
        }).count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let dateForSection = currentSections[section]
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        if Calendar.current.isDate(dateForSection, inSameDayAs: Date()) {
            return "Today - \(dateFormatter.string(from: dateForSection))"
        }

        return dateFormatter.string(from: dateForSection)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = PunchCell()

        if let validPunch = getPunchFor(section: indexPath.section, row: indexPath.row) {
            if type(of: validPunch) == PunchIn.self {
                cell = tableView.dequeueReusableCell(withIdentifier: "PunchInCell", for: indexPath) as! PunchInCell
                cell.type = .punchIn
            } else if type(of: validPunch) == PunchOut.self {
                cell = tableView.dequeueReusableCell(withIdentifier: "PunchOutCell", for: indexPath) as! PunchOutCell
                cell.type = .punchOut
            }

            cell.date = validPunch.at
            cell.isFlagged = validPunch.isFlagged
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if var validPunch = getPunchFor(section: indexPath.section, row: indexPath.row) {
            let alertTitle = validPunch.type == .punchOut ? String(format: "%@ Worked", validPunch.totalWorked.format()) : ""
            let alertMessage = "You punched \(validPunch.type) \(validPunch.time) \(validPunch.date)"

            let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .actionSheet)

            if validPunch.isFlagged {
                let removeFlagAction = UIAlertAction(title: "Remove Flag", style: .destructive) { (_) in

                    validPunch.isFlagged = false
                    self.tableView.deselectRow(at: indexPath, animated: true)

                    self.punchModel.updatePunch(validPunch, completion: { (success) in
                        if success {
                            self.punchModel.refreshPunches()
                        }
                    })

                    alertController.dismiss(animated: true, completion: nil)
                }

                alertController.addAction(removeFlagAction)
            } else {
                let addFlagAction = UIAlertAction(title: "Flag", style: .destructive) { (_) in

                    validPunch.isFlagged = true
                    self.tableView.deselectRow(at: indexPath, animated: true)

                    self.punchModel.updatePunch(validPunch, completion: { (success) in
                        if success {
                            self.punchModel.refreshPunches()
                        }
                    })

                    alertController.dismiss(animated: true, completion: nil)
                }
                alertController.addAction(addFlagAction)
            }

            let doneAction = UIAlertAction(title: "Done", style: .default) { (_) in
                self.tableView.deselectRow(at: indexPath, animated: true)
                alertController.dismiss(animated: true, completion: nil)
            }

            alertController.addAction(doneAction)

            self.navigationController?.present(alertController, animated: true) {
                print("Showing details for recordID: \(validPunch.id.recordName)")
            }
        }
    }

    @IBAction func refresh() {
        punchModel.refreshPunches()
    }

    @IBAction func backButtonPressed(_ sender: UIBarButtonItem) {
        self.tabBarController?.dismiss(animated: true, completion: nil)
    }

    @objc func modelUpdated() {
        DispatchQueue.main.async {
            if self.punchModel.datesWithPunches.count > 0 {
                self.tableView.backgroundView = nil
            }

            /*let modelChanges = diff(old: self.currentPunches, new: self.punchModel.allPunches)
            self.tableView.reload(changes: modelChanges, updateData: {
                self.currentPunches = self.punchModel.allPunches
            })*/
            
            
        }
    }

    private func getPunchFor(section: Int, row: Int) -> Punch? {
        return currentPunches.first { $0.isSameDay(currentSections[section]) }
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

}
