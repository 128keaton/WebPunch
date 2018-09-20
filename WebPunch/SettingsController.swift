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

class SettingsController: SwiftySettingsViewController {
    var storage = Storage()

    override var preferredStatusBarStyle: UIStatusBarStyle{
        return .default
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        (viewControllers.first as? UINavigationController)?.navigationBar.backgroundColor = UIColor.black
        (viewControllers.first as? UINavigationController)?.navigationBar.items?.first?.rightBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: .done, target: self, action: #selector(dismissVC))
        displaySettings()
    }
    
    @IBAction func dismissVC(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    func displaySettings() {
        settings = SwiftySettings(storage: storage, title: "Settings") {

            [Section(title: "") {
                    [
                        TextField(key: "username", title: "Username", secureTextEntry: false),
                        TextField(key: "password", title: "Password", secureTextEntry: true),
                        TextField(key: "ipAddress", title: "URL", secureTextEntry: false)
                    ]
                },
            ]
        }
    }
}
