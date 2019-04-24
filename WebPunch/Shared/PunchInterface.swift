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

extension DefaultsKeys {
    static let username = DefaultsKey<String?>("username")
    static let password = DefaultsKey<String?>("password")
    static let ipAddress = DefaultsKey<String?>("ipAddress")
    static let punchedIn = DefaultsKey<Bool?>("punchedIn")
}

enum Action {
    case punchIn
    case punchOut
    case attemptConnection
    case login
}

class PunchInterface {
    public var isLoggedIn = false
    private var observer: AnyObject?


    private lazy var alamoFireManager: SessionManager? = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 6
        configuration.timeoutIntervalForResource = 6
        let alamoFireManager = Alamofire.SessionManager(configuration: configuration)
        return alamoFireManager
    }()

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

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(reloadConnectionListener), name: NSNotification.Name("restartNetworkReachability"), object: nil)
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

    // CAN YOU FUCKING HEAR ME
    func canConnect(completion: @escaping (_ canConnect: Bool, _ reason: Int) -> ()) {
        if (self.Defaults[.username] != nil && self.Defaults[.password] != nil && self.Defaults[.ipAddress] != nil) {
            self.alamoFireManager!.request("http://\(self.Defaults[.ipAddress]!)").validate().responseData { response in
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
    func login(completion: @escaping (_ success: Bool) -> ()) {
        let parameters = ["username": Defaults[.username]!, "password": Defaults[.password]!]
        Alamofire.request("http://\(Defaults[.ipAddress]!)/login.html", parameters: parameters).response { response in
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
    func punchIn(completion: @escaping (_ success: Bool) -> ()) {
        let parameters = ["state": "PunchIn"]

        Alamofire.request("http://\(Defaults[.ipAddress]!)/webpunch.html", parameters: parameters).response { response in

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
    func punchOut(completion: @escaping (_ success: Bool) -> ()) {
        let parameters = ["state": "PunchOut"]

        Alamofire.request("http://\(Defaults[.ipAddress]!)/webpunch.html", parameters: parameters).response { response in

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

}
