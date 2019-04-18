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

    // MARK: - Properties
    let punchModel: PunchModel = PunchModel.sharedInstance

    var punches: [Punch] = []
    var noDataView: UILabel? = nil

    @IBAction func backButtonPressed(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        punchModel.delegate = self
        punchModel.refresh()
        
        noDataView = UILabel(frame: self.tableView.frame)
        noDataView?.textAlignment = .center
        noDataView?.textColor = UIColor.darkGray
        noDataView?.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        noDataView?.text = "No recorded punches"

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(punchModel, action: #selector(PunchModel.refresh), for: .valueChanged)
    }
}

// MARK: - UITableViewDataSource
extension PunchHistoryViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.punches.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell()

        let punch = self.punches[(indexPath as NSIndexPath).row]

        if punch.punchType == "In" {
            cell = tableView.dequeueReusableCell(withIdentifier: "PunchInCell", for: indexPath)
        } else if punch.punchType == "Out" {
            cell = tableView.dequeueReusableCell(withIdentifier: "PunchOutCell", for: indexPath)
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "PunchCell", for: indexPath)
        }

        if let punchCell = cell as? PunchCell {
            punchCell.punchTypeLabel?.text = punch.punchType
            punchCell.punchTimeLabel?.text = punch.punchTime
            punchCell.punchDateLabel?.text = punch.punchDate
        }

        if let punchCell = cell as? PunchInCell {
            punchCell.punchTypeLabel?.text = punch.punchType
            punchCell.punchTimeLabel?.text = punch.punchTime
            punchCell.punchDateLabel?.text = punch.punchDate
        }

        if let punchCell = cell as? PunchOutCell {
            punchCell.punchTypeLabel?.text = punch.punchType
            punchCell.punchTimeLabel?.text = punch.punchTime
            punchCell.punchDateLabel?.text = punch.punchDate
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if self.punches.count == 0 {
            tableView.backgroundView = self.noDataView!
            return 1.0
        }
        
        tableView.backgroundView = nil
        return 0.0
    }
}


// MARK: - ModelDelegate
extension PunchHistoryViewController: PunchModelDelegate {

    func modelBeginningUpdates() {
        refreshControl?.endRefreshing()
        tableView.beginUpdates()
    }

    func modelEndingUpdates() {
        let currentData = self.punches
        self.punches = PunchModel.sharedInstance.punches

        let newIndexPaths = (self.punches.enumerated()).map { IndexPath(row: $0.offset, section: 0) }
        let oldIndexPaths = (currentData.enumerated()).map { IndexPath(row: $0.offset, section: 0) }


        print("")
        print(oldIndexPaths)
        print(newIndexPaths)
        print("")

        var reloadableIndexPaths: [IndexPath] = []
        var insertableIndexPaths: [IndexPath] = []
        var removeableIndexPaths: [IndexPath] = []

        for (index, indexPath) in newIndexPaths.enumerated() {
            if currentData.indices.contains(index) {
                if currentData[index] != self.punches[index] {
                    reloadableIndexPaths.append(indexPath)
                }
            }
        }

        if newIndexPaths.count < oldIndexPaths.count {
            removeableIndexPaths.append(contentsOf: oldIndexPaths.filter { newIndexPaths.contains($0) == false })
        } else {
            insertableIndexPaths.append(contentsOf: newIndexPaths.filter { oldIndexPaths.contains($0) == false })
        }

        tableView.reloadRows(at: reloadableIndexPaths, with: .automatic)
        tableView.insertRows(at: insertableIndexPaths, with: .automatic)
        tableView.deleteRows(at: removeableIndexPaths, with: .automatic)

        tableView.endUpdates()
    }

    func errorUpdating(_ error: Error) {
        let message = error.localizedDescription

        let alertController = UIAlertController(title: "iCloud Error",
                                                message: message,
                                                preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))

        present(alertController, animated: true, completion: nil)
    }

}

