//
//  FullPayPeriodCell.swift
//  WebPunch
//
//  Created by Keaton Burleson on 4/22/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit

class PayPeriodCell: UITableViewCell{
    @IBOutlet weak var rangeLabel: UILabel?
    @IBOutlet weak var amountOfTimeLabel: UILabel?
    public var periodIsCurrent: Bool = false {
        didSet{
            self.rangeLabel?.textColor = self.periodIsCurrent ? UIColor(displayP3Red: 0.2431, green: 0.8627, blue: 0.3804, alpha: 1.0) : UIColor.gray
        }
    }
}
