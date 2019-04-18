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

    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!
    var reachabilityManager: NetworkReachabilityManager? = nil
    var isConnected = false

    init() {
        if Defaults.hasKey("ipAddress") {
            self.setupConnectionListener()
        }
    }

    public func setupConnectionListener() {
        if self.reachabilityManager != nil {
            return
        }

        reachabilityManager = NetworkReachabilityManager(host: "http://\(Defaults[.ipAddress]!)")

        reachabilityManager?.listener = { status in
            self.isConnected = (status != .notReachable && status != .unknown)
        }
        reachabilityManager?.startListening()
    }

    // CAN YOU FUCKING HEAR ME
    func canConnect(completion: @escaping (_ canConnect: Bool, _ reason: Int) -> ()) {
        if !isConnected {
            completion(false, 10)
            return
        }

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
