//
//  ViewController.swift
//  WebPunch
//
//  Created by Keaton Burleson on 9/18/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import UIKit
import Intents
import NetworkExtension

class PunchViewController: UIViewController {
    // MARK: UI elements
    @IBOutlet var punchInButton: UIButton?
    @IBOutlet var punchOutButton: UIButton?
    @IBOutlet var reconnectButton: UIButton?
    @IBOutlet var historyButton: UIButton?

    // MARK: Properties
    let punchInterface = PunchInterface()

    var lastAction: Action = .attemptConnection
    var previousConnectionStatus: NEVPNStatus = .disconnected
    var userDefaults = UserDefaults(suiteName: "group.com.webpunch")!
    var isAttemptingToConnectWithoutVPN = false
    
    // MARK: Computed Properties
    var currentDialog: UIAlertController? = nil {
        didSet {
            if let aDialog = self.currentDialog {
                present(aDialog, animated: true, completion: nil)
            }
        }
    }

    var intentsToDonate: [INIntent] {
        return [PunchInIntent(), PunchOutIntent(), PunchStatusIntent()]
    }

    // MARK: UIViewController Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        donateInteractions()
        registerForNotifications()
        punchInterface.setupConnectionListener()
        setupButtons()

        if SonicWall.useVPN && SonicWall.status == .disconnected {
            SonicWall.shared.connect()
        } else if SonicWall.useVPN && SonicWall.status == .connecting {
            reconnectButton?.startSpinning()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        if userDefaults.string(forKey: "ipAddress") != nil {
            if SonicWall.useVPN == false || SonicWall.status == .connected {
                self.attemptConnection()
            }
        } else {
            self.performSegue(withIdentifier: "showSettings", sender: self)
        }

        if SonicWall.shared.isRefreshing {
            disableButtons()
            reconnectButton?.startSpinning()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }


    // MARK: Actions
    @IBAction func attemptConnection() {
        if SonicWall.useVPN && SonicWall.status == .disconnected {
            askToConnectToVPN()
        } else {
            performRemoteAction(ofType: .attemptConnection)
        }
    }

    @IBAction func punchIn() {
        performRemoteAction(ofType: .punchIn)
    }

    @IBAction func punchOut() {
        performRemoteAction(ofType: .punchOut)
    }

    // MARK: Helpers
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(vpnStatusUpdated(_:)), name: NSNotification.Name("vpnStatusUpdated"), object: nil)
    }

    private func setupButtons() {
        reconnectButton?.setMode(mode: .loadingIndicator)
        disableButtons()
    }

    private func disableButtons() {
        punchInButton?.isEnabled = false
        punchOutButton?.isEnabled = false
    }

    private func enableButtons() {
        punchInButton?.isEnabled = true
        punchOutButton?.isEnabled = true
    }

    private func conditionallyEnableButtons() {
        self.punchInButton?.isEnabled = !(self.userDefaults[.punchedIn] ?? false)
        self.punchOutButton?.isEnabled = self.userDefaults[.punchedIn] ?? false
    }

    private func connectionAttemptStarted() {
        disableButtons()
        reconnectButton?.startSpinning()
    }

    @objc private func vpnStatusUpdated(_ notification: Notification) {
        if SonicWall.useVPN && SonicWall.status == .disconnected {
            disableButtons()
            reconnectButton?.contentLoaded(successfully: false)
            askToConnectToVPN()
        } else if SonicWall.useVPN && SonicWall.status != previousConnectionStatus {
            previousConnectionStatus = SonicWall.status
            if SonicWall.status == .connected {
                performRemoteAction(ofType: .attemptConnection)
            } else if SonicWall.status == .disconnected {
                disableButtons()
                reconnectButton?.contentLoaded(successfully: false)
                askToConnectToVPN()
            } else if SonicWall.status == .connecting {
                reconnectButton?.updateSpinningStatus(hasPartiallyLoaded: true)
            }
        }
    }

    private func askToConnectToVPN() {
        if currentDialog == nil {
            let askToConnectDialog = UIAlertController(title: "Use VPN?", message: "You have a VPN connection configured, would you like to enable the VPN connection before attempting to connect to the punch clock?", preferredStyle: .alert)

            let yesToConnectAction = UIAlertAction(title: "Connect with VPN", style: .default) { (action) in
                self.isAttemptingToConnectWithoutVPN = false
                SonicWall.shared.connect()
                self.currentDialog = nil
                askToConnectDialog.dismiss(animated: true, completion: nil)
            }

            let noToConnectAction = UIAlertAction(title: "Connect without VPN", style: .default) { (action) in
                self.currentDialog = nil
                self.isAttemptingToConnectWithoutVPN = true
                self.reconnectButton?.updateSpinningStatus(hasPartiallyLoaded: false)
                self.performRemoteAction(ofType: .attemptConnection)
                askToConnectDialog.dismiss(animated: true, completion: nil)
            }

            let stopTryingAction = UIAlertAction(title: "Stop connection attempt", style: .destructive) { (action) in
                self.currentDialog = nil
                askToConnectDialog.dismiss(animated: true, completion: nil)
            }

            askToConnectDialog.addAction(yesToConnectAction)
            askToConnectDialog.addAction(noToConnectAction)

            askToConnectDialog.addAction(stopTryingAction)

            currentDialog = askToConnectDialog
        }
    }


    private func donateInteractions() {
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
                        print("Interaction donation failed: %@", error)
                    } else {
                        print("Successfully donated interaction")
                    }
                }
            }
        }
    }

    // MARK: Garbage
    private func performRemoteAction(ofType action: Action) {
        lastAction = action
        if !SonicWall.useVPN || (SonicWall.status == .connected || SonicWall.status == .connecting) || isAttemptingToConnectWithoutVPN {
            connectionAttemptStarted()
            switch action {
            case .attemptConnection:
                punchInterface.canConnect { (canConnect, reason) in
                    self.reconnectButton?.contentLoaded(successfully: canConnect)
                    self.handleReturnStatus(success: canConnect, reason: reason, forAction: .attemptConnection)
                }
                break
            case .punchOut:
                punchInterface.login { (success) in
                    if success {
                        self.reconnectButton?.updateSpinningStatus()
                        self.punchInterface.punchOut { (success) in
                            self.reconnectButton?.contentLoaded(successfully: success)
                            self.handleReturnStatus(success: success, forAction: .punchOut)
                        }
                    } else {
                        self.handleReturnStatus(success: false, forAction: .login)
                    }
                }
                break
            case .punchIn:
                punchInterface.login { (success) in
                    if success {
                        self.reconnectButton?.updateSpinningStatus()
                        self.punchInterface.punchIn { (success) in
                            self.reconnectButton?.contentLoaded(successfully: success)
                            self.handleReturnStatus(success: success, forAction: .punchIn)
                        }
                    } else {
                        self.handleReturnStatus(success: false, forAction: .login)
                    }
                }
                break
            case .login:
                punchInterface.login { (success) in
                    self.handleReturnStatus(success: success, forAction: .login)
                }
                break
            }
        } else if SonicWall.status == .disconnected && SonicWall.useVPN {
            print("Waiting for VPN to initialize")
            SonicWall.shared.connect()
        }
    }

    private func handleReturnStatus(success: Bool, reason: Int = 0, forAction action: Action) {
        switch action {
        case .attemptConnection:
            if success {
                self.reconnectButton?.contentLoaded(successfully: true)
                self.conditionallyEnableButtons()
            } else {
                self.reconnectButton?.contentLoaded(successfully: false)
                self.disableButtons()
                handleReturnStatus(reason: reason, forAction: action)
            }
            break
        case .punchIn:
            if success {
                self.historyButton?.shake()
                UISoundService.shared.playSoundForAction(action)

                self.handleReturnStatus(reason: 1, forAction: action)
                self.punchInButton?.isEnabled = false
                self.punchOutButton?.isEnabled = true
                SonicWall.shared.disconnect()
            } else {
                self.reconnectButton?.contentLoaded(successfully: false)
                self.handleReturnStatus(reason: -1, forAction: action)
            }
            break
        case .punchOut:
            if success {
                self.historyButton?.shake()
                UISoundService.shared.playSoundForAction(action)

                self.handleReturnStatus(reason: 1, forAction: action)
                self.punchInButton?.isEnabled = true
                self.punchOutButton?.isEnabled = false
                SonicWall.shared.disconnect()
            } else {
                self.reconnectButton?.contentLoaded(successfully: false)
                self.handleReturnStatus(reason: -1, forAction: action)
            }
            break
        case .login:
            if !success {
                self.reconnectButton?.contentLoaded(successfully: false)
                self.handleReturnStatus(reason: -1, forAction: action)
            }
            break
        }
    }

    private func handleReturnStatus(reason: Int, forAction action: Action) {
        switch action {
        case .attemptConnection:
            if(reason == -1) {
                self.displayAlert(bodyText: "Unable to connect to time clock server (connection timed out)", title: "Error")
            } else if (reason == -1004) {
                self.displayAlert(bodyText: "Unable to connect to time clock server. No response was given", title: "Error")
            } else {
                self.displayAlert(bodyText: "Unable to connect to time clock server. Do you need to use a VPN?", title: "Error")
            }
            break
        case .punchIn:
            if reason == 1 {
                self.displayAlert(bodyText: "Punched in successfully", title: "Punched In")
            } else if reason == -1 {
                self.displayAlert(bodyText: "Unable to punch in", title: "Error")
            }
            break
        case .punchOut:
            if reason == 1 {
                self.displayAlert(bodyText: "Punched Out successfully", title: "Punched Out")
            } else if reason == -1 {
                self.displayAlert(bodyText: "Unable to punch out", title: "Error")
            }
            break
        case .login:
            if reason == -1 {
                self.displayAlert(bodyText: "Unable to login", title: "Error")
            }
            break
        }
    }
}
