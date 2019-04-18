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

    let punchInterface = PunchInterface()
    var activityIndicator: UIAlertController? = nil
    var isConnecting = false
    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!

    override func viewDidLoad() {
        super.viewDidLoad()

        donateInteractions()

        NotificationCenter.default.addObserver(self, selector: #selector(notificationAttemptConnection), name: NSNotification.Name("canConnect"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disableButtons), name: NSNotification.Name("cannotConnect"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disableButtons), name: NSNotification.Name("disableButtons"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopActivityIndicator), name: NSNotification.Name("stopAllActivity"), object: nil)

        punchInterface.setupConnectionListener()
        disableButtons()
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
        activityIndicator = startActivityIndicator()
        punchInterface.canConnect { (canConnect, reason) in
            // Ehh
            self.activityIndicator?.dismiss(animated: false, completion: {
                self.isConnecting = false

                if(canConnect) {
                    self.punchInButton?.isEnabled = !(self.Defaults[.punchedIn] ?? false)
                    self.punchOutButton?.isEnabled = self.Defaults[.punchedIn] ?? false
                } else {
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
            })
        }
    }


    @IBAction func punchIn() {
        activityIndicator = self.startActivityIndicator()
        punchInterface.login { (success) in
            if(success) {
                self.punchInterface.punchIn { (success) in
                    self.stopActivityIndicator()
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
        activityIndicator = self.startActivityIndicator()
        punchInterface.login { (success) in
            if(success) {
                self.punchInterface.punchOut { (success) in
                    self.stopActivityIndicator()
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

    func startActivityIndicator() -> UIAlertController {
        let alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)

        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = UIActivityIndicatorView.Style.gray
        loadingIndicator.startAnimating();

        alert.view.addSubview(loadingIndicator)
        present(alert, animated: true, completion: nil)
        return alert
    }

    @objc func stopActivityIndicator() {
        guard let activityIndicator = self.activityIndicator
            else {
                print("No activity")
                return
        }
        activityIndicator.dismiss(animated: true, completion: nil)
        self.activityIndicator = nil
    }
}

