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

    var previousConnectionStatus: NEVPNStatus = .disconnected
    var lastAction: Action = .none
    var userDefaults = UserDefaults(suiteName: "group.com.webpunch")!
    var isAttemptingToConnectWithoutVPN = false
    var currentDot: CAShapeLayer? = nil
    var didShowSettings = false

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
        punchInterface.delegate = self
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
        } else if didShowSettings == false {
            didShowSettings = true
            self.performSegue(withIdentifier: "showSettings", sender: self)
        } else {
            print("Showed settings once, still not configured")
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
        if punchInterface.lastAction != .attemptConnection {
            if SonicWall.useVPN && SonicWall.status == .disconnected && !punchInterface.didCancelAll {
                askToConnectToVPN()
            } else {
                punchInterface.performRemoteAction(ofType: .attemptConnection)
            }
        } else {
            print("Stopping connection attempt")
            punchInterface.stopAllRequests()
            self.reconnectButton?.contentLoaded(successfully: false)
            self.disableButtons()
            self.punchInterface.lastAction = .none
        }
    }

    @IBAction func punchIn() {
        punchInterface.performRemoteAction(ofType: .punchIn)
    }

    @IBAction func punchOut() {
        punchInterface.performRemoteAction(ofType: .punchOut)
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

    private func addDotToButton(_ button: UIButton) {
        let xCoord: CGFloat = (button.frame.width / 2.0)
        let yCoord: CGFloat = (button.frame.height / 2.0) - 55.0
        let radius: CGFloat = 15.0

        let dotPath = UIBezierPath(ovalIn: CGRect(x: xCoord, y: yCoord, width: radius, height: radius))

        let dotLayer = CAShapeLayer()
        dotLayer.path = dotPath.cgPath
        dotLayer.fillColor = self.view.tintColor.cgColor

        let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
        fadeInAnimation.duration = 0.3
        fadeInAnimation.fromValue = 0.0
        fadeInAnimation.toValue = 1.0
        dotLayer.opacity = 1.0


        button.layer.addSublayer(dotLayer)
        dotLayer.add(fadeInAnimation, forKey: "addDot")
        currentDot = dotLayer
    }

    private func removeDotFromButton() {
        if let dotLayer = currentDot {
            CATransaction.begin()

            let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
            fadeOutAnimation.duration = 0.3
            fadeOutAnimation.fromValue = 1.0
            fadeOutAnimation.toValue = 0.0
            dotLayer.add(fadeOutAnimation, forKey: "removeDot")

            CATransaction.setCompletionBlock { [weak self] in
                dotLayer.removeFromSuperlayer()
                self?.currentDot = nil
            }

            CATransaction.commit()
        }
    }

    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        removeDotFromButton()
        addDotToButton(punchOutButton!)
    }

    @objc private func vpnStatusUpdated(_ notification: Notification) {
        if SonicWall.useVPN && SonicWall.status == .disconnected {
            disableButtons()
            reconnectButton?.contentLoaded(successfully: false)
            askToConnectToVPN()
        } else if SonicWall.useVPN && SonicWall.status != previousConnectionStatus {
            previousConnectionStatus = SonicWall.status
            if SonicWall.status == .connected {
                punchInterface.performRemoteAction(ofType: .attemptConnection)
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
        if currentDialog == nil && (lastAction == .none || lastAction != .disconnect) && !punchInterface.didCancelAll {
            let askToConnectDialog = UIAlertController(title: "Retry with VPN?", message: "You have a VPN connection configured, would you like to enable the VPN connection before attempting to connect to the punch clock?", preferredStyle: .alert)

            let yesToConnectAction = UIAlertAction(title: "Connect with VPN", style: .default) { (action) in
                self.isAttemptingToConnectWithoutVPN = false
                SonicWall.shared.connect()
                self.currentDialog = nil
                self.punchInterface.lastAction = .none
                askToConnectDialog.dismiss(animated: true, completion: nil)
            }

            let noToConnectAction = UIAlertAction(title: "Connect without VPN", style: .default) { (action) in
                self.currentDialog = nil
                self.isAttemptingToConnectWithoutVPN = true
                self.reconnectButton?.updateSpinningStatus(hasPartiallyLoaded: false)
                self.punchInterface.performRemoteAction(ofType: .attemptConnection)
                askToConnectDialog.dismiss(animated: true, completion: nil)
            }

            let stopTryingAction = UIAlertAction(title: "Stop connection attempt", style: .destructive) { (action) in
                self.currentDialog = nil
                self.punchInterface.lastAction = .none
                askToConnectDialog.dismiss(animated: true, completion: nil)
            }

            askToConnectDialog.addAction(yesToConnectAction)
            askToConnectDialog.addAction(noToConnectAction)
            askToConnectDialog.addAction(stopTryingAction)

            currentDialog = askToConnectDialog
        }
    }

    private func askToDisconnectFromVPN() {
        if currentDialog == nil && (lastAction == .none || lastAction != .disconnect) {
            let askToDisconnectDialog = UIAlertController(title: "Disconnect from VPN?", message: "It appears you currently are connected to a VPN, would you like to disconnect now?", preferredStyle: .alert)

            let yesToDisconnect = UIAlertAction(title: "Yes", style: .destructive) { (action) in
                self.currentDialog = nil
                self.disconnectFromVPN()

                askToDisconnectDialog.dismiss(animated: true, completion: nil)
            }

            let noToDisconnect = UIAlertAction(title: "No", style: .default) { (action) in
                self.currentDialog = nil
                askToDisconnectDialog.dismiss(animated: true, completion: nil)
            }

            let alwaysDisconnect = UIAlertAction(title: "Always", style: .destructive) { (action) in
                self.currentDialog = nil
                self.disconnectFromVPN()

                self.userDefaults.set(true, forKey: "alwaysDisconnectFromVPN")
                self.userDefaults.synchronize()

                askToDisconnectDialog.dismiss(animated: true, completion: nil)
            }

            askToDisconnectDialog.addAction(yesToDisconnect)
            askToDisconnectDialog.addAction(alwaysDisconnect)
            askToDisconnectDialog.addAction(noToDisconnect)

            currentDialog = askToDisconnectDialog
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
}
extension PunchViewController: PunchInterfaceDelegate {
    func connectionAttemptStarted() {
        self.disableButtons()
        self.reconnectButton?.startSpinning()
    }

    func connectionAttemptSucceeded() {
        self.reconnectButton?.contentLoaded(successfully: true)
        self.conditionallyEnableButtons()
    }

    func connectionAttemptFailed() {
        self.reconnectButton?.contentLoaded(successfully: false)
        self.disableButtons()
    }

    func punchInSucceeded() {
        self.historyButton?.shake()
        UISoundService.shared.playSoundForAction(.punchIn)

        self.punchInButton?.isEnabled = false
        self.punchOutButton?.isEnabled = true

        self.removeDotFromButton()
        self.addDotToButton(punchInButton!)

        if userDefaults.bool(forKey: "alwaysDisconnectFromVPN") == true {
            self.disconnectFromVPN()
        } else {
            self.askToDisconnectFromVPN()
        }
    }

    func punchInFailed() {
        self.reconnectButton?.contentLoaded(successfully: false)
    }

    func punchOutSucceeded() {
        self.historyButton?.shake()
        UISoundService.shared.playSoundForAction(.punchOut)

        self.punchInButton?.isEnabled = true
        self.punchOutButton?.isEnabled = false

        self.removeDotFromButton()
        self.addDotToButton(punchOutButton!)

        if userDefaults.bool(forKey: "alwaysDisconnectFromVPN") == true {
            self.disconnectFromVPN()
        } else {
            self.askToDisconnectFromVPN()
        }
    }

    func punchOutFailed() {
        self.reconnectButton?.contentLoaded(successfully: false)
    }

    func loginSucceeded() {
        self.reconnectButton?.updateSpinningStatus()
    }

    func loginFailed() {
        self.reconnectButton?.contentLoaded(successfully: false)
    }

    func connectToVPN() {
        self.lastAction = .attemptConnection
        SonicWall.shared.connect()
    }

    func disconnectFromVPN() {
        self.lastAction = .disconnect
        SonicWall.shared.disconnect()
    }

    func handleAlertMessage(message: String, title: String) {
        self.displayAlert(bodyText: message, title: title)
    }
}
