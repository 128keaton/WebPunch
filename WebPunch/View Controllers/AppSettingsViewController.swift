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
    static let vpnConnectionName = DefaultsKey<String?>("vpnConnectionName")
    static let useVPN = DefaultsKey<Bool?>("useVPN")
    static let punchClockAddress = DefaultsKey<String?>("ipAddress")
}

class Storage: SettingsStorageType {
    subscript(key: DefaultsKey<Bool?>) -> Bool? {
        get {
            return Defaults.bool(forKey: key._key)
        }
        set(newValue) {
            Defaults.set(newValue, forKey: key._key)
        }
    }

    subscript(key: DefaultsKey<Double?>) -> Double? {
        get {
            return Defaults.double(forKey: key._key)
        }
        set(newValue) {
            Defaults.set(newValue, forKey: key._key)
        }
    }

    subscript(key: DefaultsKey<Int?>) -> Int? {
        get {
            return Defaults.integer(forKey: key._key)
        }
        set(newValue) {
            Defaults.set(newValue, forKey: key._key)
        }
    }

    subscript(key: DefaultsKey<String?>) -> String? {
        get {
            return Defaults.string(forKey: key._key)
        }
        set(newValue) {
            Defaults.set(newValue, forKey: key._key)
        }
    }
    var userDefaults = UserDefaults(suiteName: "group.com.webpunch")!
}

class AppSettingsViewController: SwiftySettingsViewController {
    var storage = Storage()

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
        dismiss(animated: true, completion: nil)
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
                        Switch(key: "useVPN", title: "SonicWall Mobile Connect", defaultValue: false, icon: nil, valueChangedClosure: { (key, switchValue) in
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
                        Switch(key: "useVPN", title: "SonicWall Mobile Connect", defaultValue: false, icon: nil, valueChangedClosure: { (key, switchValue) in
                            Defaults[.useVPN] = switchValue
                            if !switchValue {
                                self.displayNonVPNSettings()
                            }
                        }),
                        TextField(key: "vpnConnectionName", title: "Connection Name", placeholder: "blah VPN", autoCapitalize: false, keyboardType: .default),
                    ]
                }
            ]
        }
    }
}
