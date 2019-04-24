//
//  AppDelegate.swift
//  WebPunch
//
//  Created by Keaton Burleson on 9/18/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    let mobileConnect = SonicWall.shared

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Will use in intents UI
        NotificationCenter.default.addObserver(self, selector: #selector(connectToVPN), name: NSNotification.Name("connectToVPN"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disconnectFromVPN), name: NSNotification.Name("disconnectFromVPN"), object: nil)

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
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
        }
        return true
    }
}

