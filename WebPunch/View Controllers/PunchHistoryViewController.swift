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
    var currentPunches: [MatchedPunches] = []
    var flippedCells: [PunchCell] = []

    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!


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

        NotificationCenter.default.addObserver(self, selector: #selector(modelEndedUpdates(_:)), name: PunchModel.modelEndUpdates, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(modelBeganUpdates(_:)), name: PunchModel.modelBeginUpdates, object: nil)

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
        return punchModel.matchedPunches.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 108.0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return punchModel.matchedPunches[section].punches.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let dateForSection = getDateFor(section: section) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none

            if Calendar.current.isDate(dateForSection, inSameDayAs: Date()) {
                return "Today - \(dateFormatter.string(from: dateForSection))"
            }

            return dateFormatter.string(from: dateForSection)
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = PunchCell()

        let validPunch = punchModel.matchedPunches[indexPath.section].punches[indexPath.row]

        if validPunch.type == .punchIn {
            cell = tableView.dequeueReusableCell(withIdentifier: "PunchInCell", for: indexPath) as! PunchInCell
        } else if validPunch.type == .punchOut {
            cell = tableView.dequeueReusableCell(withIdentifier: "PunchOutCell", for: indexPath) as! PunchOutCell
        }

        cell.data = validPunch

        return cell
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard let punchCell = tableView.cellForRow(at: indexPath) as? PunchCell else {
            return nil
        }

        guard var punch = punchCell.data else {
            return nil
        }

        if !punch.isFlagged {
            let flagTitle = NSLocalizedString("Flag", comment: "Flag this punch")
            let flagAction = UITableViewRowAction(style: .default, title: flagTitle) { (action, indexPath) in
                punch.isFlagged = true
                punchCell.data = punch

                self.punchModel.updatePunch(punch, completion: { (didComplete) in
                    print("Punch \(punch.id.recordName) is now flagged")
                })
            }
            flagAction.backgroundColor = UIColor.orange

            return [flagAction]
        } else if punch.isFlagged {
            let clearTitle = NSLocalizedString("Clear", comment: "Clear flag")
            let clearAction = UITableViewRowAction(style: .default, title: clearTitle) { (action, indexPath) in
                punch.isFlagged = false
                punchCell.data = punch

                self.punchModel.updatePunch(punch, completion: { (didComplete) in
                    print("Punch \(punch.id.recordName) is no longer flagged")
                })
            }
            clearAction.backgroundColor = self.view.tintColor
            return [clearAction]
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let selectedCell = tableView.cellForRow(at: indexPath) as? PunchCell {
            tableView.deselectRow(at: indexPath, animated: true)
            selectedCell.flipView()

            if selectedCell.displayingData {
                UISoundService.shared.playShowDataSound()
                flippedCells.append(selectedCell)
            } else {
                UISoundService.shared.playHideDataSound()
                flippedCells.removeAll { $0 == selectedCell }
            }

            flippedCells.sort { $0.data!.at.compare($1.data!.at) == .orderedDescending }
        }
    }

    private func flipAllCellsBack() {
        flippedCells.enumerated().forEach { (arg) in
            let (index, cell) = arg
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 * Double(index), execute: {
                if cell.displayingData == true {
                    cell.flipView()
                }
            })
        }
        flippedCells.removeAll()
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let punchCell = cell as? PunchCell else {
            return
        }

        if punchCell.displayingData == true {
            punchCell.flipView()
        }
    }

    @IBAction func refresh() {
        punchModel.refreshPunches()
        flipAllCellsBack()
    }

    @IBAction func backButtonPressed(_ sender: UIBarButtonItem) {
        self.tabBarController?.dismiss(animated: true, completion: nil)
    }

    @objc func modelBeganUpdates(_ notification: Notification) {
        if let _currentPunches = notification.object as? [MatchedPunches] {
            self.currentPunches = _currentPunches
            print("Beginning updates")
        }
    }

    @objc func modelEndedUpdates(_ notification: Notification) {
        if let newPunches = notification.object as? [MatchedPunches] {
            DispatchQueue.main.async {
                if self.flippedCells.count > 0 {
                    self.flipAllCellsBack()
                }

                self.tableView.animateRowAndSectionChanges(oldData: self.currentPunches, newData: newPunches)
            }
        }
    }

    private func getDateFor(section: Int) -> Date? {
        if punchModel.matchedPunches.indices.contains(section) {
            return punchModel.matchedPunches[section].key
        }
        return nil
    }

    private func getPunchesFor(section: Int) -> [OperationalPunch]? {
        if punchModel.matchedPunches.indices.contains(section) {
            return punchModel.matchedPunches[section].punches
        }
        return nil
    }

    private func getPunchFor(section: Int, row: Int) -> Punch? {
        if let punchesInSection = getPunchesFor(section: section),
            punchesInSection.indices.contains(row) {
            return punchesInSection[row]
        }
        return nil
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
