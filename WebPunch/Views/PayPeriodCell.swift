//
//  FullPayPeriodCell.swift
//  WebPunch
//
//  Created by Keaton Burleson on 4/22/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit

class PayPeriodCell: UITableViewCell {
    @IBOutlet weak var rangeLabel: UILabel?
    @IBOutlet weak var amountOfTimeLabel: UILabel?
    @IBOutlet weak var punchesAmount: UILabel?
    @IBOutlet weak var earnedAmountLabel: UILabel?
    
    public var periodIsCurrent: Bool = false {
        didSet {
            self.punchesAmount?.textColor = self.periodIsCurrent ? self.contentView.tintColor : .gray
        }
    }
}
