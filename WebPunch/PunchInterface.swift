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

    // CAN YOU FUCKING HEAR ME
    func canConnect(completion: @escaping (_ canConnect: Bool, _ reason: Int) -> ()) {
        if (Defaults[.username] != nil && Defaults[.password] != nil && Defaults[.ipAddress] != nil) {
            let manager = Alamofire.SessionManager.default
            manager.session.configuration.timeoutIntervalForRequest = 10

            Alamofire.request("http://\(Defaults[.ipAddress]!)").validate().responseData { response in
                switch response.result {
                case .success:
                    completion(true, 0)
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
                    return completion(true)
                } else {
                    print(utf8Text)
                }
            }
            return completion(false)
        }
    }

}
