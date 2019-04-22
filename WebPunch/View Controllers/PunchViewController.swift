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

class PunchViewController: UIViewController {
    @IBOutlet var punchInButton: UIButton?
    @IBOutlet var punchOutButton: UIButton?
    @IBOutlet var reconnectButton: UIButton?

    let punchInterface = PunchInterface()
    var isConnecting = false
    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!
    var intentsToDonate: [INIntent] {
        return [PunchInIntent(), PunchOutIntent(), PunchStatusIntent()]
    }

    var shouldAttemptConnection = false

    override func viewDidLoad() {
        super.viewDidLoad()

        donateInteractions()
        registerForNotifications()
        punchInterface.setupConnectionListener()
        disableButtons()
    }

    override func viewDidAppear(_ animated: Bool) {
        disableButtons()
        if shouldAttemptConnection == true {
            reconnectButton?.tintColor = UIColor(displayP3Red: 0.8667, green: 0.0745, blue: 0.2941, alpha: 1.0)
            startRotating()
        } else {
            setUnconfigured()
        }
    }

    func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(isConfigured), name: NSNotification.Name("isConfigured"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(isNotConfigured), name: NSNotification.Name("isNotConfigured"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disableButtons), name: NSNotification.Name("canNotConnect"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(notificationAttemptConnection), name: NSNotification.Name("canConnect"), object: nil)
    }

    @objc func isConfigured() {
        shouldAttemptConnection = true
    }

    @objc func isNotConfigured() {
        shouldAttemptConnection = false
        stopRotating()
        setUnconfigured()
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

    @objc private func disableButtons() {
        punchInButton?.isEnabled = false
        punchOutButton?.isEnabled = false
    }

    private func enableButtons() {
        punchInButton?.isEnabled = true
        punchOutButton?.isEnabled = true
    }

    private func setUnconfigured() {
        UIView.animate(withDuration: 0.5) {
            self.reconnectButton?.tintColor = .yellow
        }
    }

    private func setConnected() {
        UIView.animate(withDuration: 0.5) {
            self.reconnectButton?.tintColor = UIColor(displayP3Red: 0.2431, green: 0.8627, blue: 0.3804, alpha: 1.0)
        }
    }

    private func setDisconnected() {
        UIView.animate(withDuration: 0.5) {
            self.reconnectButton?.tintColor = UIColor(displayP3Red: 0.2431, green: 0.8627, blue: 0.3804, alpha: 1.0)
        }
    }

    private func startRotating() {
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0.0
        rotateAnimation.toValue = CGFloat(.pi * 2.0)
        rotateAnimation.duration = 2.0
        rotateAnimation.repeatCount = .greatestFiniteMagnitude

        self.reconnectButton!.layer.add(rotateAnimation, forKey: nil)
    }

    func stopRotating() {
        self.reconnectButton?.layer.removeAllAnimations()
    }

    func donateInteractions() {
        for intent in intentsToDonate {
            switch type(of: intent) {
            case is PunchInIntent.Type:
                intent.suggestedInvocationPhrase = "Punch in"
            case is PunchOutIntent.Type:
                intent.suggestedInvocationPhrase = "Punch out"
            case is PunchStatusIntent.Type:
                intent.suggestedInvocationPhrase = "Am I punched in?"
            default:
                print("Unknown intent: \(intent)")
            }

            let interaction = INInteraction(intent: intent, response: nil)

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
    }

    @IBAction func attemptConnection() {
        if shouldAttemptConnection {
            startRotating()
            disableButtons()
            punchInterface.canConnect { (canConnect, reason) in
                self.isConnecting = false
                self.stopRotating()
                if(canConnect) {
                    self.setConnected()
                    self.punchInButton?.isEnabled = !(self.Defaults[.punchedIn] ?? false)
                    self.punchOutButton?.isEnabled = self.Defaults[.punchedIn] ?? false
                } else {
                    self.setDisconnected()
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
    }

    @IBAction func punchIn() {
        if shouldAttemptConnection {
            startRotating()
            disableButtons()
            punchInterface.login { (success) in
                if(success) {
                    self.punchInterface.punchIn { (success) in
                        self.stopRotating()
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
    }

    @IBAction func punchOut() {
        if shouldAttemptConnection {
            startRotating()
            disableButtons()
            punchInterface.login { (success) in
                self.stopRotating()
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
    }
}
