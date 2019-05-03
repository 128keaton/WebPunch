//
//  PunchInterface.swift
//  WebPunch
//
//  Created by Keaton Burleson on 9/18/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyUserDefaults
import NetworkExtension

extension DefaultsKeys {
    static let username = DefaultsKey<String?>("username")
    static let password = DefaultsKey<String?>("password")
    static let ipAddress = DefaultsKey<String?>("ipAddress")
    static let punchedIn = DefaultsKey<Bool?>("punchedIn")
}

enum Action: String {
    case punchIn = "punchIn"
    case punchOut = "punchOut"
    case attemptConnection = "attemptConnection"
    case disconnect = "disconnect"
    case login = "login"
    case none = "none"
}

class PunchInterface {
    public static let shared = PunchInterface()

    public var isLoggedIn = false
    public var delegate: PunchInterfaceDelegate? = nil

    public var lastAction: Action = .attemptConnection


    private let queue = DispatchQueue(label: "com.keaton.webpunch.queue", qos: .background, attributes: .concurrent)

    private var currentBackgroundTaskID: UIBackgroundTaskIdentifier? = nil

    private lazy var alamoFireManager: SessionManager? = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.keaton.webpunch.connection")
        configuration.timeoutIntervalForRequest = 6
        configuration.timeoutIntervalForResource = 6
        let alamoFireManager = Alamofire.SessionManager(configuration: configuration)
        return alamoFireManager
    }()

    var vpnStatus: NEVPNStatus = .disconnected
    var vpnEnabled = false {
        didSet {
            connectWithoutVPN = !self.vpnEnabled
        }
    }
    var connectWithoutVPN = true
    var didCancelAll = false

    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!
    var reachabilityManager: NetworkReachabilityManager? = nil
    var isConnected = false {
        didSet {
            if self.isConnected {
                NotificationCenter.default.post(name: NSNotification.Name("canConnect"), object: nil)
            } else {
                NotificationCenter.default.post(name: NSNotification.Name("canNotConnect"), object: nil)
            }
        }
    }
    var isConfigured: Bool = false {
        didSet {
            if self.isConfigured {
                NotificationCenter.default.post(name: NSNotification.Name("isConfigured"), object: nil)
            } else {
                NotificationCenter.default.post(name: NSNotification.Name("isNotConfigured"), object: nil)
            }
        }
    }

    private init() {
        registerForNotifications()
    }

    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(vpnStatusUpdated(_:)), name: NSNotification.Name("vpnStatusUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadConnectionListener), name: NSNotification.Name("restartNetworkReachability"), object: nil)
    }

    @objc private func vpnStatusUpdated(_ notification: Notification) {
        if let newStatus = notification.object as? NEVPNStatus {
            self.vpnStatus = newStatus
        }
    }

    public func setupConnectionListener(reload: Bool = false) {
        if self.reachabilityManager != nil && reload == false {
            return
        }

        if Defaults.hasKey(.ipAddress) {
            self.reachabilityManager = NetworkReachabilityManager(host: "http://\(Defaults[.ipAddress]!)")
            self.isConfigured = true
            self.reachabilityManager?.listener = { status in
                self.isConnected = (status == .reachable(.ethernetOrWiFi))
                return
            }
            self.reachabilityManager?.startListening()
        }
    }

    @objc public func reloadConnectionListener() {
        self.setupConnectionListener(reload: true)
    }

    public func stopAllRequests() {
        didCancelAll = true
        self.alamoFireManager?.session.getAllTasks { (tasks) in
            tasks.forEach({ $0.cancel() })
        }
        Alamofire.SessionManager.default.session.getAllTasks { (tasks) in
            tasks.forEach({ $0.cancel() })
        }
    }

    @objc private func receiveBackgroundTaskID(_ notification: Notification) {
        if let taskID = notification.object as? UIBackgroundTaskIdentifier {
            self.currentBackgroundTaskID = taskID
        }
    }

    public func connectLoginPunchOut(completion: @escaping(_ canConnect: Bool, _ didLogin: Bool, _ didPunchOut: Bool) -> ()) {
        self.canConnect { (canConnect, statusCode) in
            print("Connection status code: \(statusCode)")
            if (canConnect) {
                self.login(completion: { (didLogin) in
                    if (didLogin) {
                        self.punchOut(completion: { (didPunchOut) in
                            completion(canConnect, didLogin, didPunchOut)
                        })
                    } else {
                        completion(canConnect, didLogin, false)
                    }
                })
            } else {
                completion(false, false, false)
            }
        }
    }

    public func connectLoginPunchIn(completion: @escaping(_ canConnect: Bool, _ didLogin: Bool, _ didPunchIn: Bool) -> ()) {
        self.canConnect { (canConnect, _) in
            if (canConnect) {
                self.login(completion: { (didLogin) in
                    if (didLogin) {
                        self.punchIn(completion: { (didPunchIn) in
                            completion(canConnect, didLogin, didPunchIn)
                        })
                    } else {
                        completion(canConnect, didLogin, false)
                    }
                })
            } else {
                completion(canConnect, false, false)
            }
        }
    }

    // CAN YOU FUCKING HEAR ME
    public func canConnect(completion: @escaping (_ canConnect: Bool, _ reason: Int) -> ()) {
        if (self.Defaults[.username] != nil && self.Defaults[.password] != nil && self.Defaults[.ipAddress] != nil) {
            self.alamoFireManager!.request("http://\(self.Defaults[.ipAddress]!)").validate().responseData() { response in
                switch response.result {
                case .success:
                    if response.data != nil {
                        self.login(completion: { (didLogin) in
                            completion(didLogin, 0)
                        })
                    } else {
                        // Unknown state
                        completion(false, -999)
                    }
                case .failure(let error):
                    if (error as NSError).code == 53 {
                        print("Retrying connection..might have left to connect VPN")
                        self.canConnect(completion: { (didComplete, statusCode) in
                            completion(didComplete, statusCode)
                        })
                    } else if (error as NSError).code == -1004 {
                        print("The time clock server most likely crashed")
                        completion(false, -1004)
                    } else if (error as NSError).code == -1001 {
                        completion(false, -1001)
                    } else {
                        print("Error thrown (code \((error as NSError).code)): \(error.localizedDescription)")
                        // Unknown state
                        completion(false, -999)
                    }
                }
            }
        } else {
            completion(false, 2)
        }
    }

    // LOG THE FUCK IN
    public func login(completion: @escaping (_ success: Bool) -> ()) {
        let parameters = ["username": Defaults[.username]!, "password": Defaults[.password]!]
        self.alamoFireManager!.request("http://\(Defaults[.ipAddress]!)/login.html", parameters: parameters).response { response in
            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                if utf8Text.contains("you last punched") {
                    print("Logged in")
                    self.isLoggedIn = true
                    if(utf8Text.contains("you last punched out")) {
                        self.Defaults[.punchedIn] = false
                    } else if (utf8Text.contains("you last punched in")) {
                        self.Defaults[.punchedIn] = true
                    }
                    return completion(true)
                } else {
                    print(utf8Text)
                }
            } else {
                return completion(false)
            }
        }
    }

    // PUNCH THE FUCK IN
    public func punchIn(completion: @escaping (_ success: Bool) -> ()) {
        let parameters = ["state": "PunchIn"]

        self.alamoFireManager!.request("http://\(Defaults[.ipAddress]!)/webpunch.html", parameters: parameters).response { response in

            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                if(utf8Text.contains("IN AT")) {
                    self.Defaults[.punchedIn] = true
                    self.isLoggedIn = false
                    PunchModel.sharedInstance.punchIn()
                    return completion(true)
                }
            }
            return completion(false)
        }
    }

    // PUNCH THE FUCK OUT
    public func punchOut(completion: @escaping (_ success: Bool) -> ()) {
        let parameters = ["state": "PunchOut"]

        self.alamoFireManager!.request("http://\(Defaults[.ipAddress]!)/webpunch.html", parameters: parameters).response { response in

            if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                if(utf8Text.contains("Recorded")) {
                    self.Defaults[.punchedIn] = false
                    self.isLoggedIn = false
                    PunchModel.sharedInstance.punchOut()
                    return completion(true)
                } else {
                    print(utf8Text)
                }
            }
            return completion(false)
        }
    }

    public func performRemoteAction(ofType action: Action) {
        didCancelAll = false
        lastAction = action
        if !vpnEnabled || (vpnStatus == .connected || vpnStatus == .connecting) || connectWithoutVPN {
            self.delegate?.connectionAttemptStarted?()
            switch action {
            case .attemptConnection:
                self.canConnect { (canConnect, reason) in
                    self.handleReturnStatus(success: canConnect, reason: reason, forAction: .attemptConnection)
                }
                break
            case .punchOut:
                self.login { (success) in
                    if success {
                        self.delegate?.loginSucceeded?()
                        self.punchOut { (success) in
                            self.handleReturnStatus(success: success, forAction: .punchOut)
                        }
                    } else {
                        self.handleReturnStatus(success: false, forAction: .login)
                    }
                }
                break
            case .punchIn:
                self.login { (success) in
                    if success {
                        self.delegate?.loginSucceeded?()
                        self.punchIn { (success) in
                            self.handleReturnStatus(success: success, forAction: .punchIn)
                        }
                    } else {
                        self.handleReturnStatus(success: false, forAction: .login)
                    }
                }
                break
            case .login:
                self.login { (success) in
                    self.handleReturnStatus(success: success, forAction: .login)
                }
                break
            case .disconnect:
                break
            case .none:
                break
            }
        } else if vpnStatus == .disconnected && vpnEnabled {
            print("Waiting for VPN to initialize")
            self.delegate?.connectToVPN?()
        }
    }

    private func handleReturnStatus(success: Bool, reason: Int = 0, forAction action: Action) {
        switch action {
        case .attemptConnection:
            if success {
                self.delegate?.connectionAttemptSucceeded?()
            } else {
                self.delegate?.connectionAttemptFailed?()
                self.handleAlertMessageForReason(reason, forAction: action)
            }
            break
        case .punchIn:
            if success {
                self.delegate?.punchInSucceeded?()
            } else {
                self.delegate?.punchInFailed?()
                self.handleAlertMessageForReason(-1, forAction: action)
            }
            break
        case .punchOut:
            if success {
                self.delegate?.punchOutSucceeded?()
                self.handleAlertMessageForReason( 1, forAction: action)
            } else {
                self.delegate?.punchOutFailed?()
                self.handleAlertMessageForReason( -1, forAction: action)
            }
            break
        case .login:
            if !success {
                self.delegate?.loginFailed?()
                self.handleAlertMessageForReason(-1, forAction: action)
            }
            break
        case .disconnect:
            break
        case .none:
            break
        }
    }

    private func handleAlertMessageForReason(_ reason: Int, forAction action: Action) {
        switch action {
        case .attemptConnection:
            if reason == -1 && didCancelAll == false {
                delegate?.handleAlertMessage?(message: "Unable to connect to the time clock server. The connection timed out.", title: "Connection Error")
            } else if reason == -1004 {
                delegate?.handleAlertMessage?(message: "Unable to connect to the time clock server. The server did not return a response.", title: "Connection Error")
            } else {
                delegate?.handleAlertMessage?(message: "Unable to connect to the time clock server. Do you need to use a VPN?", title: "Connection Error")
            }
            break
        case .punchIn:
            if reason == 1 && didCancelAll == false {
                delegate?.handleAlertMessage?(message: "Punched in successfully", title: "Punched In")
            } else if reason == -1 {
                delegate?.handleAlertMessage?(message: "Unable to punch in", title: "Error")
            }
            break
        case .punchOut:
            if reason == 1 && didCancelAll == false {
                delegate?.handleAlertMessage?(message: "Punched out successfully", title: "Punched Out")
            } else if reason == -1 {
                delegate?.handleAlertMessage?(message: "Unable to punch out", title: "Error")
            }
            break
        case .login:
            if reason == -1 && didCancelAll == false {
                delegate?.handleAlertMessage?(message: "Unable to login", title: "Error")
            }
            break
        case .disconnect:
            break
        case .none:
            break
        }
    }

}

@objc protocol PunchInterfaceDelegate {
    @objc optional func connectionAttemptSucceeded()
    @objc optional func connectionAttemptFailed()
    @objc optional func connectionAttemptStarted()

    @objc optional func punchInSucceeded()
    @objc optional func punchInFailed()

    @objc optional func punchOutSucceeded()
    @objc optional func punchOutFailed()

    @objc optional func loginSucceeded()
    @objc optional func loginFailed()

    @objc optional func connectToVPN()
    @objc optional func disconnectFromVPN()

    @objc optional func handleAlertMessage(message: String, title: String)
}
