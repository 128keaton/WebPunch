//
//  AppDelegate.swift
//  WebPunch
//
//  Created by Keaton Burleson on 9/18/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import UIKit
import UserNotifications
import SwiftyUserDefaults

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var notificationHandler: NotificationHandler? = nil

    let mobileConnect = SonicWall.shared

    let notificationCenter = UNUserNotificationCenter.current()
    let options: UNAuthorizationOptions = [.alert, .sound, .badge]
    let backgroundQueue = DispatchQueue(label: "BackgroundNotificationQueue", qos: .default)

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Will use in intents UI
        NotificationCenter.default.addObserver(self, selector: #selector(connectToVPN), name: NSNotification.Name("connectToVPN"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disconnectFromVPN), name: NSNotification.Name("disconnectFromVPN"), object: nil)

        notificationCenter.delegate = notificationHandler
        notificationCenter.requestAuthorization(options: options) {
            (didAllow, error) in
            if !didAllow {
                print("User has declined notifications")
            } else if let authorizationError = error {
                print(authorizationError)
            }

            self.notificationHandler = NotificationHandler.shared
        }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        if SonicWall.status != .connecting && SonicWall.status != .disconnecting {
            SonicWall.shared.refreshStatus()
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        SonicWall.shared.disconnect()
    }

    @objc func connectToVPN() {
        if mobileConnect.useVPN {
            mobileConnect.connect()
        }
    }

    @objc func disconnectFromVPN() {
        mobileConnect.disconnect()
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if url.scheme == "serverauditor",
            let action = url.valueOf("action"),
            let status = url.valueOf("status") {

            if status == "success" {
                if action == "connect" {
                    SonicWall.shared.updateStatus(newStatus: .connected)
                } else if action == "disconnect" {
                    SonicWall.shared.updateStatus(newStatus: .disconnected)
                }
            } else {
                SonicWall.shared.updateStatus(newStatus: .invalid)
            }
        } else if url.scheme == "webpunch", let rawAction = url.host,
            let action = Action(rawValue: rawAction), let _notificationHandler = notificationHandler {

            _notificationHandler.handleNotificationAction(action)
        }
        return true
    }
}


