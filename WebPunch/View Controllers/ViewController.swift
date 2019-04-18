//
//  ViewController.swift
//  WebPunch
//
//  Created by Keaton Burleson on 9/18/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import UIKit
import Alamofire
import Intents
import os.log

class ViewController: UIViewController {
    @IBOutlet var punchInButton: UIButton?
    @IBOutlet var punchOutButton: UIButton?
    @IBOutlet var separator: UIView?
    @IBOutlet var reconnectButton: UIButton?

    let punchInterface = PunchInterface()
    var isConnecting = false
    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!

    override func viewDidLoad() {
        super.viewDidLoad()

        donateInteractions()

        separator?.layer.cornerRadius = 2

        NotificationCenter.default.addObserver(self, selector: #selector(notificationAttemptConnection), name: NSNotification.Name("canConnect"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disableButtons), name: NSNotification.Name("cannotConnect"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disableButtons), name: NSNotification.Name("disableButtons"), object: nil)

        punchInterface.setupConnectionListener()
        disableButtons()
    }

    override func viewDidAppear(_ animated: Bool) {
        startPulsing()
    }

    @objc func notificationAttemptConnection() {
        if !isConnecting {
            isConnecting = true
            self.attemptConnection()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    @objc func disableButtons() {
        reconnectButton?.tintColor = UIColor(displayP3Red: 0.8667, green: 0.0745, blue: 0.2941, alpha: 1.0)
        punchInButton?.isEnabled = false
        punchOutButton?.isEnabled = false
    }

    func donateInteractions() {
        var intent: INIntent

        intent = PunchInIntent()

        intent.suggestedInvocationPhrase = "Punch in"

        var interaction = INInteraction(intent: intent, response: nil)

        interaction.donate { (error) in
            if error != nil {
                if let error = error as NSError? {
                    os_log("Interaction donation failed: %@", log: OSLog.default, type: .error, error)
                } else {
                    os_log("Successfully donated interaction")
                }
            }
        }

        intent = PunchOutIntent()

        intent.suggestedInvocationPhrase = "Punch out"

        interaction = INInteraction(intent: intent, response: nil)

        interaction.donate { (error) in
            if error != nil {
                if let error = error as NSError? {
                    os_log("Interaction donation failed: %@", log: OSLog.default, type: .error, error)
                } else {
                    os_log("Successfully donated interaction")
                }
            }
        }

        intent = PunchStatusIntent()

        intent.suggestedInvocationPhrase = "Am I punched in?"

        interaction = INInteraction(intent: intent, response: nil)

        interaction.donate { (error) in
            if error != nil {
                if let error = error as NSError? {
                    os_log("Interaction donation failed: %@", log: OSLog.default, type: .error, error)
                } else {
                    os_log("Successfully donated interaction")
                }
            }
        }
    }

    @IBAction func attemptConnection() {
        startPulsing()
        punchInterface.canConnect { (canConnect, reason) in
            self.isConnecting = false
            self.stopPulsing()
            if(canConnect) {
                // [UIColor colorWithRed:0.2431 green:0.8627 blue:0.3804 alpha:1.0]
                self.reconnectButton?.tintColor = UIColor(displayP3Red: 0.2431, green: 0.8627, blue: 0.3804, alpha: 1.0)
                self.punchInButton?.isEnabled = !(self.Defaults[.punchedIn] ?? false)
                self.punchOutButton?.isEnabled = self.Defaults[.punchedIn] ?? false
            } else {
                // [UIColor colorWithRed:0.8667 green:0.0745 blue:0.2941 alpha:1.0]
                self.reconnectButton?.tintColor = UIColor(displayP3Red: 0.8667, green: 0.0745, blue: 0.2941, alpha: 1.0)
                self.punchInButton?.isEnabled = false
                self.punchOutButton?.isEnabled = false

                if(reason == 1) {
                    self.displayAlert(bodyText: "Unable to connect to time clock server (connection timed out)", title: "Error")
                } else if(reason == 2) {
                    self.performSegue(withIdentifier: "showSettings", sender: self)
                } else if (reason == 10) {
                    self.displayAlert(bodyText: "Unable to connect to time clock server", title: "Error")
                }
            }
        }
    }

    @IBAction func punchIn() {
        startPulsing()
        punchInterface.login { (success) in
            if(success) {
                self.punchInterface.punchIn { (success) in
                    self.stopPulsing()
                    if(success) {
                        self.displayAlert(bodyText: "Punched in successfully", title: "Punched In")
                        self.punchInButton?.isEnabled = false
                        self.punchOutButton?.isEnabled = true
                    } else {
                        self.displayAlert(bodyText: "Unable to punch in", title: "Error")
                    }
                }
            } else {
                self.displayAlert(bodyText: "Unable to login", title: "Error")
            }
        }
    }

    @IBAction func punchOut() {
        startPulsing()
        punchInterface.login { (success) in
            self.stopPulsing()
            if(success) {
                self.punchInterface.punchOut { (success) in
                    if(success) {
                        self.displayAlert(bodyText: "Punched Out successfully", title: "Punched Out")
                        self.punchInButton?.isEnabled = true
                        self.punchOutButton?.isEnabled = false
                    } else {
                        self.displayAlert(bodyText: "Unable to punch out", title: "Error")
                    }
                }
            } else {
                self.displayAlert(bodyText: "Unable to login", title: "Error")
            }
        }

    }

    func displayAlert(bodyText: String, title: String) {
        let alertController = UIAlertController(title: title, message: bodyText, preferredStyle: .alert)
        let dismissButton = UIAlertAction(title: "Ok", style: .default) { (action) in
            alertController.dismiss(animated: true, completion: nil)
        }
        alertController.addAction(dismissButton)
        self.present(alertController, animated: true, completion: nil)
    }

    func startPulsing() {
        let pulseAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        pulseAnimation.duration = 1
        pulseAnimation.fromValue = 0
        pulseAnimation.toValue = 1
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .greatestFiniteMagnitude
        self.separator!.layer.add(pulseAnimation, forKey: "animateOpacity")
    }

    func stopPulsing() {
        self.separator?.layer.removeAllAnimations()
        self.separator?.alpha = 0.0
    }
}

