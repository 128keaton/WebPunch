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
import AudioToolbox

class PunchViewController: UIViewController {
    @IBOutlet var punchInButton: UIButton?
    @IBOutlet var punchOutButton: UIButton?
    @IBOutlet var reconnectButton: UIButton?
    @IBOutlet var historyButton: UIButton?

    let punchInterface = PunchInterface()
    let punchInSoundURL = URL(string: "/System/Library/Audio/UISounds/nano/WalkieTalkieActiveStart_Haptic.caf")
    let punchOutSoundURL = URL(string: "/System/Library/Audio/UISounds/nano/WalkieTalkieActiveEnd_Haptic.caf")
    
    var isConnecting = false
    var shouldReconnect = false
    
    var punchInSoundID: SystemSoundID? = nil
    var punchOutSoundID: SystemSoundID? = nil

    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!
    var intentsToDonate: [INIntent] {
        return [PunchInIntent(), PunchOutIntent(), PunchStatusIntent()]
    }

    var shouldAttemptConnection = false {
        didSet {
            if self.shouldAttemptConnection == true {
                self.attemptConnection()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        donateInteractions()
        registerForNotifications()
        punchInterface.setupConnectionListener()
        disableButtons()
    }

    override func viewDidAppear(_ animated: Bool) {
        if shouldReconnect && shouldAttemptConnection  {
            disableButtons()
            attemptConnection()
        }
    }

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(isConfigured), name: NSNotification.Name("isConfigured"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(isNotConfigured), name: NSNotification.Name("isNotConfigured"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundShouldReconnect), name: NSNotification.Name("connectionNeedsRefreshing"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disableButtons), name: NSNotification.Name("canNotConnect"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(attemptConnection), name: NSNotification.Name("canConnect"), object: nil)
    }

    @objc func backgroundShouldReconnect() {
        shouldReconnect = true
    }

    @objc func isConfigured() {
        shouldAttemptConnection = true
        if !isConnecting {
            attemptConnection()
        }
    }

    @objc func isNotConfigured() {
        shouldAttemptConnection = false
        stopRotating()
        setUnconfigured()
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
        self.stopRotating()
        UIView.animate(withDuration: 0.5) {
            self.reconnectButton?.tintColor = UIColor(displayP3Red: 0.2431, green: 0.8627, blue: 0.3804, alpha: 1.0)
        }
    }

    private func setDisconnected() {
        self.stopRotating()
        UIView.animate(withDuration: 0.5) {
            self.reconnectButton?.tintColor = UIColor(displayP3Red: 0.8667, green: 0.0784, blue: 0.2902, alpha: 1.0)
        }
    }

    private func setConnecting() {
        UIView.animate(withDuration: 0.5) {
            self.reconnectButton?.tintColor = UIColor(hue: 0.5472, saturation: 1, brightness: 0.93, alpha: 1.0)
        }
    }

    private func didPunchOut() {
        if let soundID = punchOutSoundID {
            AudioServicesPlaySystemSound(soundID);
        } else {
            var newSoundID = SystemSoundID()
            AudioServicesCreateSystemSoundID(punchOutSoundURL! as CFURL, &newSoundID)
            AudioServicesPlaySystemSound(newSoundID);
            punchOutSoundID = newSoundID
        }
        
        UIView.animate(withDuration: 0.6, delay: 0, options: .curveEaseInOut, animations: {
            self.historyButton?.tintColor = UIColor(displayP3Red: 0.8667, green: 0.0784, blue: 0.2902, alpha: 1.0)
            self.historyButton?.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        }, completion: { (didComplete) in
            if didComplete {
                UIView.animate(withDuration: 0.4, delay: 0.6, options: .curveEaseOut, animations: {
                    self.historyButton?.tintColor = .white
                })
            }
        })

        UIView.animate(withDuration: 0.4, delay: 0.3, options: .curveEaseInOut, animations: {
            self.historyButton?.transform = CGAffineTransform(rotationAngle: CGFloat.pi * 2.0)
        })
    }

    private func didPunchIn() {
        if let soundID = punchInSoundID {
            AudioServicesPlaySystemSound(soundID);
        } else {
            var newSoundID = SystemSoundID()
            AudioServicesCreateSystemSoundID(punchInSoundURL! as CFURL, &newSoundID)
            AudioServicesPlaySystemSound(newSoundID);
            punchInSoundID = newSoundID
        }
        
        UIView.animate(withDuration: 0.6, delay: 0, options: .curveEaseInOut, animations: {
            self.historyButton?.tintColor = UIColor(displayP3Red: 0.2431, green: 0.8627, blue: 0.3804, alpha: 1.0)
            self.historyButton?.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        }, completion: { (didComplete) in
            if didComplete {
                UIView.animate(withDuration: 0.4, delay: 0.6, options: .curveEaseOut, animations: {
                    self.historyButton?.tintColor = .white
                })
            }
        })

        UIView.animate(withDuration: 0.4, delay: 0.3, options: .curveEaseInOut, animations: {
            self.historyButton?.transform = CGAffineTransform(rotationAngle: CGFloat.pi * 2.0)
        })
    }

    private func startRotating() {
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0.0
        rotateAnimation.toValue = CGFloat(.pi * 2.0)
        rotateAnimation.duration = 2.0
        rotateAnimation.repeatCount = .greatestFiniteMagnitude

        self.setConnecting()
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

    @IBAction @objc func attemptConnection() {
        if shouldAttemptConnection && !isConnecting {
            isConnecting = true
            startRotating()
            disableButtons()
            punchInterface.canConnect { (canConnect, reason) in
                self.isConnecting = false
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
                            self.didPunchIn()
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
                            self.didPunchOut()
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

