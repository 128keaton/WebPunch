//
//  PunchCell.swift
//  WebPunch
//
//  Created by Keaton Burleson on 4/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit

class PunchInCell: PunchCell { }
class PunchOutCell: PunchCell { }

class PunchCell: UITableViewCell {
    @IBOutlet weak var punchTypeLabel: UILabel?
    @IBOutlet weak var punchTimeLabel: UILabel?
    @IBOutlet weak var punchDateLabel: UILabel?

    var type: PunchType = .punchIn {
        didSet {
            configureView()
        }
    }

    var date: Date? = nil {
        didSet {
            configureView()
        }
    }

    var isFlagged: Bool = false {
        didSet {
            configureView()
        }
    }

    private var flaggedDot: CAShapeLayer? = nil

    override func awakeFromNib() {
        super.awakeFromNib()
        configureView()
    }

    private func configureView() {
        if type == .punchIn {
            punchTypeLabel?.text = "↓In"
            punchTypeLabel?.textColor = UIColor(displayP3Red: 0.2431, green: 0.8627, blue: 0.3804, alpha: 1.0)
        } else if type == .punchOut {
            punchTypeLabel?.text = "↑Out"
            punchTypeLabel?.textColor = UIColor(displayP3Red: 0.8667, green: 0.0784, blue: 0.2902, alpha: 1.0)
        }

        if let validDate = self.date {
            let dateFormatter = DateFormatter()

            dateFormatter.dateFormat = "MM/dd"
            punchDateLabel?.text = "on \(dateFormatter.string(from: validDate))"

            dateFormatter.dateFormat = "h:mm a"
            punchTimeLabel?.text = "at \(dateFormatter.string(from: validDate))"
        }

        if isFlagged {
            if flaggedDot != nil {
                return
            }

            let radius: CGFloat = 10.0
            let xCoord: CGFloat = 4
            let yCoord: CGFloat = (self.contentView.frame.height / 2.0) - (radius / 2.0)

            let dotPath = UIBezierPath(ovalIn: CGRect(x: xCoord, y: yCoord, width: radius, height: radius))

            let dotLayer = CAShapeLayer()
            dotLayer.path = dotPath.cgPath
            dotLayer.fillColor = UIColor.orange.cgColor

            let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
            fadeInAnimation.duration = 0.3
            fadeInAnimation.fromValue = 0.0
            fadeInAnimation.toValue = 1.0
            dotLayer.opacity = 1.0


            self.contentView.layer.addSublayer(dotLayer)
            dotLayer.add(fadeInAnimation, forKey: "addDot")

            flaggedDot = dotLayer
        } else if let currentFlaggedDot = flaggedDot {
            currentFlaggedDot.removeFromSuperlayer()
        }
    }
}
