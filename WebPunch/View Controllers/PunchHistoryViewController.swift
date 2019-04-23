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
    @IBOutlet weak var historyButton: UIBarButtonItem?

    var displayMode: DisplayMode = .punchesByDay {
        didSet {
            displayModeChanged()
        }
    }

    @IBAction func backButtonPressed(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func switchModeButtonPressed(sender: AnyObject, forEvent event: UIEvent) {
        if displayMode == .punchesByDay {
            displayMode = .punchesByWeek
        } else if displayMode == .punchesByWeek {
            displayMode = .punchesByPeriods
        } else {
            displayMode = .punchesByDay
        }
    }

    override func viewDidLoad() {
        self.tableView.tableFooterView = UIView(frame: CGRect.zero)

        createNoDataView()
        setupModel()
        addRefreshControl()
    }

    private func displayModeChanged() {
        let transitionOptions: UIView.AnimationOptions = [.transitionFlipFromTop, .showHideTransitionViews]
        let historyButtonView = self.historyButton?.value(forKey: "view") as! UIView

        playSoundForTransition()

        UIView.transition(with: self.view, duration: 0.3, options: transitionOptions, animations: {
            historyButtonView.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
            DispatchQueue.main.async {
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
                self.tableView.reloadData()
            }
        })
        UIView.animate(withDuration: 0.3, delay: 0.15, options: .curveEaseInOut, animations: {
            historyButtonView.transform = CGAffineTransform(rotationAngle: CGFloat.pi * 2.0)
        })
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
            if self.weekPayPeriods.count == 0 {
                self.tableView.backgroundView = self.noDataView!
            }
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 108.0
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if displayMode == .punchesByWeek {
            let payPeriod = self.weekPayPeriods[indexPath.section]
            self.displayAlert(bodyText: "You have worked \(payPeriod.amountWorked.readableUnit) between \(payPeriod)", title: "Week Total")
        }

        tableView.deselectRow(at: indexPath, animated: true)
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

        if let punchCell = cell as? PunchCell,
            let punch = punch {
            punchCell.punchTypeLabel?.text = punch.punchType
            punchCell.punchTimeLabel?.text = punch.punchTime
            punchCell.punchDateLabel?.text = punch.punchDate
        }

        if let punchCell = cell as? PunchInCell,
            let punch = punch {
            punchCell.punchTypeLabel?.text = punch.punchType
            punchCell.punchTimeLabel?.text = punch.punchTime
            punchCell.punchDateLabel?.text = punch.punchDate
        }

        if let punchCell = cell as? PunchOutCell,
            let punch = punch {
            punchCell.punchTypeLabel?.text = punch.punchType
            punchCell.punchTimeLabel?.text = punch.punchTime
            punchCell.punchDateLabel?.text = punch.punchDate
        }

        if let periodCell = cell as? PayPeriodCell {
            let fullPayPeriod = self.fullPayPeriods[indexPath.section].weekPayPeriods[indexPath.row]
            periodCell.isUserInteractionEnabled = false
            periodCell.periodIsCurrent = fullPayPeriod.incomplete
            periodCell.rangeLabel?.text = fullPayPeriod.description
            periodCell.amountOfTimeLabel?.text = fullPayPeriod.amountWorked.readableUnit
            periodCell.punchesAmount?.text = "\(fullPayPeriod.punches.count)"
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

