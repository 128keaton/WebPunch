//
//  SettingsController.swift
//  WebPunch
//
//  Created by Keaton Burleson on 9/18/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit
import SwiftySettings
import SwiftyUserDefaults

extension DefaultsKeys {
    static let vpnUsername = DefaultsKey<String?>("vpnUsername")
    static let vpnAddress = DefaultsKey<String?>("vpnAddress")
    static let useVPN = DefaultsKey<Bool?>("useVPN")
}

class Storage: SettingsStorageType {
    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!

    subscript(key: String) -> Bool? {
        get {
            return Defaults[key].bool
        }
        set {
            Defaults[key] = newValue
        }
    }
    subscript(key: String) -> Float? {
        get {
            return Float(Defaults[key].doubleValue)
        }
        set {
            Defaults[key] = newValue
        }
    }
    subscript(key: String) -> Int? {
        get {
            return Defaults[key].int
        }
        set {
            Defaults[key] = newValue
        }
    }
    subscript(key: String) -> String? {
        get {
            return Defaults[key].string
        }
        set {
            Defaults[key] = newValue
        }
    }
}

class AppSettingsViewController: SwiftySettingsViewController {
    var storage = Storage()
    var keyChain = KeychainService()

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        (viewControllers.first as? UINavigationController)?.navigationBar.items?.first?.rightBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: .done, target: self, action: #selector(dismissVC))
        (viewControllers.first as? UINavigationController)?.navigationBar.barStyle = .black

        if Defaults[.useVPN] == true {
            displaySettings()
        } else {
            displayNonVPNSettings()
        }
    }
    
    @objc func dismissVC(_ sender: Any) {
        self.isEditing = false
        dismiss(animated: true, completion: {
            if Defaults[.useVPN] == true {
                VPN().connectVPN()
            } else {
                VPN().disconnectVPN()
            }
        })
    }

    func displayNonVPNSettings() {
        settings = SwiftySettings(storage: storage, title: "Settings") {
            [
                Section(title: "Time Clock") {
                    [
                        TextField(key: "username", title: "Username", placeholder: "me", autoCapitalize: false, keyboardType: .default),
                        TextField(key: "password", title: "Password", secureTextEntry: true, autoCapitalize: false, keyboardType: .default),
                        TextField(key: "ipAddress", title: "URL", placeholder: "http://punchclock.address", autoCapitalize: false, keyboardType: .URL)
                    ]
                },
                Section(title: "Pay") {
                    [
                        TextField(key: "hourlyPay", title: "Hourly Pay", placeholder: "17.00", autoCapitalize: false, keyboardType: .decimalPad),
                        TextField(key: "taxRate", title: "Tax rate", placeholder: "1.25", autoCapitalize: false, keyboardType: .decimalPad),
                    ]
                },
                Section(title: "Connection Settings") {
                    [
                        Switch(key: "useVPN", title: "VPN", defaultValue: false, icon: nil, valueChangedClosure: { (key, switchValue) in
                            Defaults[.useVPN] = switchValue
                            if switchValue {
                                self.displaySettings()
                            }
                        }),
                    ]
                }
            ]
        }
    }

    func displaySettings() {
        settings = SwiftySettings(storage: storage, title: "Settings") {
            [
                Section(title: "Time Clock") {
                    [
                        TextField(key: "username", title: "Username", placeholder: "me", autoCapitalize: false, keyboardType: .default),
                        TextField(key: "password", title: "Password", secureTextEntry: true, autoCapitalize: false, keyboardType: .default),
                        TextField(key: "ipAddress", title: "URL", placeholder: "http://punchclock.address", autoCapitalize: false, keyboardType: .URL)

                    ]
                },
                Section(title: "Connection Settings") {
                    [
                        Switch(key: "useVPN", title: "VPN", defaultValue: false, icon: nil, valueChangedClosure: { (key, switchValue) in
                            Defaults[.useVPN] = switchValue
                            if !switchValue {
                                self.displayNonVPNSettings()
                            }
                        }),
                        TextField(key: "vpnUsername", title: "Username", placeholder: "me@vpn.address", autoCapitalize: false, keyboardType: .default),
                        TextField(key: "vpnPassword", title: "Password", secureTextEntry: true, valueChangedClosure: { (key, value) in
                            self.keyChain.save(key: key, value: value)
                        }),
                        TextField(key: "vpnSharedSecret", title: "Shared Secret", secureTextEntry: true, valueChangedClosure: { (key, value) in
                            self.keyChain.save(key: key, value: value)
                        }),

                        TextField(key: "vpnAddress", title: "URL", placeholder: "http://vpn.address", autoCapitalize: false, keyboardType: .URL)
                    ]
                }
            ]
        }
    }
}
