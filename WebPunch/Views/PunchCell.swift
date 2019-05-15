//
//  PunchCell.swift
//  WebPunch
//
//  Created by Keaton Burleson on 4/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit
import UICountingLabel

class PunchInCell: PunchCell { }
class PunchOutCell: PunchCell { }

class PunchCell: UITableViewCell {
    @IBOutlet weak var punchTypeLabel: UILabel!
    @IBOutlet weak var punchTimeLabel: UILabel!
    @IBOutlet weak var punchDateLabel: UILabel!
    @IBOutlet weak var dataView: UIView!
    @IBOutlet weak var normalView: UIView!

    @IBOutlet weak var bottomMarginConstraint: NSLayoutConstraint?

    @IBOutlet weak var earnedLabel: UICountingLabel?
    @IBOutlet weak var hoursLabel: UICountingLabel?
    @IBOutlet weak var otherLabel: UILabel?

    var data: Punch? = nil {
        didSet {
            configureView()
        }
    }

    private (set) public var displayingData: Bool = false

    private var flaggedDot: CAShapeLayer? = nil
    private var earnedAmount: Double = 0.0
    private var hoursAmount: Double = 0.0
    private var showEarned: Bool = false
    private var showHours: Bool = false

    private var Defaults = UserDefaults(suiteName: "group.com.webpunch")!

    override func awakeFromNib() {
        super.awakeFromNib()
        configureView()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if bottomMarginConstraint != nil {
            bottomMarginConstraint?.isActive = false
        }

        self.normalView.heightAnchor.constraint(equalTo: contentView.heightAnchor).isActive = true
        self.normalView.widthAnchor.constraint(equalTo: contentView.widthAnchor).isActive = true
        self.normalView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        self.normalView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true

        self.dataView.widthAnchor.constraint(equalTo: contentView.widthAnchor).isActive = true
        self.dataView.heightAnchor.constraint(equalTo: contentView.heightAnchor).isActive = true
        self.dataView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        self.dataView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
    }

    public func flipView() {
        if displayingData {
            print("Hiding data")
            UIView.transition(with: contentView, duration: 0.6, options: .transitionFlipFromTop, animations: { () -> Void in
                self.contentView.insertSubview(self.normalView, aboveSubview: self.dataView)
            })
            self.displayingData = false
        } else {
            print("Showing data")
            UIView.transition(with: contentView, duration: 0.6, options: .transitionFlipFromTop, animations: { () -> Void in
                self.contentView.insertSubview(self.dataView, aboveSubview: self.normalView)
            })
            self.displayingData = true
            self.dataViewDidShow()
        }
    }

    private func dataViewDidShow() {
        print("DataView did show")

        if showHours, let _hoursLabel = hoursLabel {
            UIView.animate(withDuration: 0.3, animations: {
                _hoursLabel.alpha = 1.0
            }) { (didComplete) in
                _hoursLabel.formatBlock = { value in
                    return String(format: "%@ Worked", TimeInterval(value).format())
                }
                _hoursLabel.countFromZero(to: CGFloat(self.hoursAmount))
            }
        }

        if showEarned, let _earnedLabel = earnedLabel {
            UIView.animate(withDuration: 0.3, animations: {
                _earnedLabel.alpha = 1.0
            }) { (didComplete) in
                _earnedLabel.formatBlock = { value in
                    String(format: "~$%.02f Earned", value)
                }
                _earnedLabel.countFromZero(to: CGFloat(self.earnedAmount))
            }
        }

        if self.data!.type == .punchOut && !showEarned && !showHours {
            let aLabel = UILabel(frame: self.dataView.frame)
            aLabel.textAlignment = .center
            aLabel.text = "You punched out \(self.data!.time) \(self.data!.date)"
            aLabel.textColor = UIColor.lightText
            aLabel.font = UIFont.systemFont(ofSize: 19)

            self.dataView.addSubview(aLabel)
            self.otherLabel = aLabel
        } else if self.data!.type == .punchOut && (showEarned || showHours),
            let badLabel = self.otherLabel {
            badLabel.removeFromSuperview()
            self.otherLabel = nil
        }
    }

    private func configureView() {
        if let validData = self.data {
            if validData.type == .punchIn {
                punchTypeLabel?.text = "↓In"
                punchTypeLabel?.textColor = UIColor(displayP3Red: 0.2431, green: 0.8627, blue: 0.3804, alpha: 1.0)
            } else if validData.type == .punchOut {
                punchTypeLabel?.text = "↑Out"
                punchTypeLabel?.textColor = UIColor(displayP3Red: 0.8667, green: 0.0784, blue: 0.2902, alpha: 1.0)
            }

            punchDateLabel?.text = "on \(validData.date)"
            punchTimeLabel?.text = "at \(validData.time)"

            if let _otherLabel = otherLabel {
                _otherLabel.text = "You punched \(validData.type == .punchIn ? "in" : "out") \(validData.time) \(validData.date)"
            }

            if let _earnedLabel = earnedLabel {
                if let payString = Defaults.object(forKey: "hourlyPay") as? String,
                    let payDouble = Double(payString),
                    let taxRateString = Defaults.object(forKey: "taxRate") as? String,
                    let taxRateDouble = Double(taxRateString),
                    validData.totalWorked.hasHours || validData.totalWorked.hasMinutes {
                    let amountPreTax = payDouble * validData.totalWorked.getHours()
                    let amountTaxed = amountPreTax - (amountPreTax * taxRateDouble)
                    _earnedLabel.text = "$0.00 Earned"
                    earnedAmount = amountTaxed
                    showEarned = true
                } else {
                    showEarned = false
                }
                _earnedLabel.alpha = 0.0
            }

            if let _hoursLabel = hoursLabel {
                if validData.totalWorked.hasHours || validData.totalWorked.hasMinutes {
                    print(validData.totalWorked.getMinutes())
                    _hoursLabel.text = "0:00 Worked"
                    hoursAmount = validData.totalWorked
                    showHours = true
                } else {
                    showHours = false
                }
                _hoursLabel.alpha = 0.0
            }
            
            if validData.isFlagged, flaggedDot == nil {
                let radius: CGFloat = 10.0
                let xCoord: CGFloat = 6
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
            } else if !validData.isFlagged, let currentFlaggedDot = flaggedDot {
                currentFlaggedDot.removeFromSuperlayer()
            }
        }
    }
}
