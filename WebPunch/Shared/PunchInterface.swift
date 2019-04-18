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

class PunchInterface {
    public var isLoggedIn = false

    var previousStatus: NetworkReachabilityManager.NetworkReachabilityStatus? = nil
    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!
    var reachabilityManager: NetworkReachabilityManager? = nil
    var isConnected = false {
        didSet {
            if self.isConnected == true {
                NotificationCenter.default.post(name: NSNotification.Name("canConnect"), object: nil)
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

        self.reachabilityManager = NetworkReachabilityManager(host: "http://\(Defaults[.ipAddress]!)")
        self.reachabilityManager?.listener = { status in
            if self.previousStatus == nil || reload != true {
                self.isConnected = (status == .reachable(.ethernetOrWiFi))
                self.previousStatus = status
                return
            }
            
            self.isConnected = (status == .reachable(.ethernetOrWiFi))
            return
        }
        self.reachabilityManager?.startListening()
    }

    @objc public func reloadConnectionListener() {
        self.setupConnectionListener(reload: true)
    }

    // CAN YOU FUCKING HEAR ME
    func canConnect(completion: @escaping (_ canConnect: Bool, _ reason: Int) -> ()) {
        if (self.Defaults[.username] != nil && self.Defaults[.password] != nil && self.Defaults[.ipAddress] != nil) {
            Alamofire.request("http://\(self.Defaults[.ipAddress]!)").validate().responseData { response in
                switch response.result {
                case .success:
                    if response.data != nil {
                        self.login(completion: { (didLogin) in
                            completion(didLogin, 0)
                        })
                    } else {
                        // Unknown state
                        completion(false, 0)
                    }
                case .failure(let error):
                    print(error)
                    completion(false, 1)
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
            }
            return completion(false)
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