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
    var canUseNotifications = false
    var storage = Storage()
    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!

    let mobileConnect = SonicWall.shared
    let notificationCenter = UNUserNotificationCenter.current()
    let options: UNAuthorizationOptions = [.alert, .sound, .badge]
    let backgroundQueue = DispatchQueue(label: "BackgroundNotificationQueue", qos: .default)

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Will use in intents UI
        NotificationCenter.default.addObserver(self, selector: #selector(connectToVPN), name: NSNotification.Name("connectToVPN"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disconnectFromVPN), name: NSNotification.Name("disconnectFromVPN"), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(scheduleHoursNotification(notification:)), name: PunchModel.didPunchIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(scheduleHoursNotification(notification: testing:)), name: PunchModel.didPunchInTesting, object: nil)

        notificationCenter.delegate = self
        notificationCenter.requestAuthorization(options: options) {
            (didAllow, error) in
            if !didAllow {
                print("User has declined notifications")
            } else if let authorizationError = error {
                print(authorizationError)
            }
            self.canUseNotifications = didAllow
        }

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

    @objc func scheduleHoursNotification(notification: Notification) {
        if let notificationID = notification.object as? String, canUseNotifications == true {
            scheduleHoursNotification(forPunchID: notificationID)
        } else if canUseNotifications == false {
            print("User has declined notifications")
        }
    }

    @objc func scheduleHoursNotification(notification: Notification, testing: Bool = true) {
        if let notificationID = notification.object as? String, canUseNotifications == true {
            scheduleHoursNotification(forPunchID: notificationID, testing: true)
        } else if canUseNotifications == false {
            print("User has declined notifications")
        }
    }

    func scheduleHoursNotification(forPunchID punchID: String, hours: Int = 8, testing: Bool = false) {
        var timeIntervalSeconds: TimeInterval = Double(hours) * pow(60.0, 2.0)
        if testing {
            print("Scheduling notification for 5 seconds in the future")
            timeIntervalSeconds = 5
        }

        scheduleNotification(type: .hoursBeyondEight, notificationID: punchID, delay: timeIntervalSeconds, testing: testing)
    }

    private func scheduleNotification(type: NotificationType, notificationID: String = String.random(), delay: TimeInterval = 5, testing: Bool = false, lastAction: Action = .none) {
        let notificationContent = UNMutableNotificationContent()
        let userActions = "User Actions"
        var category: UNNotificationCategory? = nil

        notificationContent.categoryIdentifier = userActions

        #if DEBUG
            notificationContent.badge = 1
        #endif

        print("Creating notification of type: \(type)")
        switch type {
        case .hoursBeyondEight:
            notificationContent.title = "Hours Alert"
            notificationContent.body = "You have been punched in for more than eight hours."

            let punchOutAction = UNNotificationAction(identifier: NotificationIdentifier.punchOut.rawValue, title: "Punch Out", options: [.destructive])
            category = UNNotificationCategory(identifier: userActions, actions: [punchOutAction], intentIdentifiers: [], options: [])

        case .punchedInSuccessfully:
            notificationContent.userInfo["lastAction"] = Action.punchIn.rawValue
            notificationContent.title = "Punched In"
            notificationContent.body = "You have successfully punched in."

        case .punchedOutSuccessfully:
            notificationContent.userInfo["lastAction"] = Action.punchOut.rawValue
            notificationContent.title = "Punched Out"
            notificationContent.body = "You have successfully punched out."

        case .errorPunchingIn:
            notificationContent.userInfo["lastAction"] = Action.punchIn.rawValue
            notificationContent.title = "Error"
            notificationContent.body = "Unable to punch in."

        case .errorPunchingOut:
            notificationContent.userInfo["lastAction"] = Action.punchOut.rawValue
            notificationContent.title = "Error"
            notificationContent.body = "Unable to punch out."

        case .unableToLogin:
            notificationContent.userInfo["lastAction"] = lastAction.rawValue
            notificationContent.title = "Error"
            notificationContent.body = "Unable to login to punch clock server. Verify username and password in settings."
            let openSettingsAction = UNNotificationAction(identifier: NotificationIdentifier.openSettings.rawValue, title: "Open Settings", options: [])
            let retryAction = UNNotificationAction(identifier: NotificationIdentifier.retryConnection.rawValue, title: "Retry", options: [])

            category = UNNotificationCategory(identifier: userActions, actions: [openSettingsAction, retryAction], intentIdentifiers: [], options: [])

        case .unableToConnect:
            notificationContent.userInfo["lastAction"] = lastAction.rawValue
            notificationContent.title = "Error"
            notificationContent.body = "Unable to connect to punch clock server. Verify connection settings."

            let openSettingsAction = UNNotificationAction(identifier: NotificationIdentifier.openSettings.rawValue, title: "Open Settings", options: [])
            let retryAction = UNNotificationAction(identifier: NotificationIdentifier.retryConnection.rawValue, title: "Retry", options: [])

            if let useVPN = storage[.useVPN], useVPN == true, SonicWall.status != .connected {
                notificationContent.body = "Unable to connect to punch clock server. Verify connection settings or try connecting with a VPN"

                let connectToVPNAction = UNNotificationAction(identifier: NotificationIdentifier.connectToVPN.rawValue, title: "Connect to VPN", options: [])
                category = UNNotificationCategory(identifier: userActions, actions: [openSettingsAction, retryAction, connectToVPNAction], intentIdentifiers: [], options: [])
            } else {
                category = UNNotificationCategory(identifier: userActions, actions: [openSettingsAction, retryAction], intentIdentifiers: [], options: [])
            }
            print("Created notification!")
            print(notificationContent)


        case .vpnConnectionTimedOut:
            notificationContent.userInfo["lastAction"] = lastAction.rawValue
            notificationContent.title = "Error"
            notificationContent.body = "Connection to VPN server timed out. Verify VPN connection settings or retry."

            let openSettingsAction = UNNotificationAction(identifier: NotificationIdentifier.openSettings.rawValue, title: "Open Settings", options: [])
            let retryAction = UNNotificationAction(identifier: NotificationIdentifier.connectToVPN.rawValue, title: "Retry", options: [])

            category = UNNotificationCategory(identifier: userActions, actions: [openSettingsAction, retryAction], intentIdentifiers: [], options: [])
        }

        scheduleNotification(notificationContent: notificationContent, delay: delay, notificationID: notificationID, category: category)
    }


    private func scheduleNotification(notificationContent: UNMutableNotificationContent, delay: TimeInterval, notificationID: String, category: UNNotificationCategory? = nil) {
        notificationContent.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: notificationContent, trigger: trigger)

        print("Adding \(request.identifier) successfully")

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                print("Error \(error.localizedDescription)")
            } else {
                print("Added \(request.identifier) successfully")
            }
        }


        if let category = category {
            notificationCenter.setNotificationCategories([category])
        }
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
        } else if url.scheme == "webpunch",
            let rawAction = url.host,
            let action = Action(rawValue: rawAction) {
            handleNotificationAction(action)
        }
        return true
    }

    private func handleNotificationAction(_ action: Action) {
        switch action {
        case .punchOut:
            print("Punching out...")
            let punchOutTaskID = UIApplication.shared.beginBackgroundTask(withName: "punchOut") {
                print("Punch out request timed out in the background")
            }

            PunchInterface.shared.connectLoginPunchOut { (didConnect, didLogin, didPunchOut) in
                UIApplication.shared.endBackgroundTask(punchOutTaskID)


                if(didConnect && didLogin && didPunchOut) {
                    self.scheduleNotification(type: .punchedOutSuccessfully)
                } else if (didConnect && didLogin && !didPunchOut) {
                    self.scheduleNotification(type: .errorPunchingOut)
                } else if (didConnect && !didLogin && !didPunchOut) {
                    self.scheduleNotification(type: .unableToLogin)
                } else if (!didConnect && !didLogin && !didPunchOut) {
                    self.scheduleNotification(type: .unableToConnect)
                } else {
                    self.scheduleNotification(type: .unableToConnect)
                    print("Dunno what happened")
                }

            }
            break
        default:
            print("Action \(action) not handled")
        }
    }

    enum NotificationType {
        case errorPunchingOut
        case errorPunchingIn

        case punchedOutSuccessfully
        case punchedInSuccessfully

        case unableToConnect
        case unableToLogin

        case vpnConnectionTimedOut

        case hoursBeyondEight
    }

    enum NotificationIdentifier: String {
        case openSettings = "openSettings"
        case retryConnection = "retryConnection"
        case connectToVPN = "connectToVPN"
        case punchIn = "punchIn"
        case punchOut = "punchOut"
    }
}
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case UNNotificationDismissActionIdentifier:
            print("Dismiss Action")
        case UNNotificationDefaultActionIdentifier:
            print("Default")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                print("Show alert on mainView")
            }
        case NotificationIdentifier.punchOut.rawValue:
            handleNotificationAction(Action(rawValue: response.actionIdentifier)!)
        case NotificationIdentifier.punchIn.rawValue:
            handleNotificationAction(Action(rawValue: response.actionIdentifier)!)
        case NotificationIdentifier.openSettings.rawValue:
            print("Should open application settings")
        case NotificationIdentifier.connectToVPN.rawValue:
            SonicWall.shared.connect { (didConnect) in
                if let lastActionRaw = userInfo["lastAction"] as? String,
                    let lastAction = Action(rawValue: lastActionRaw) {
                    print("Handle action: \(lastAction)")

                    if (didConnect) {
                        self.handleNotificationAction(lastAction)
                    } else {
                        self.scheduleNotification(type: .vpnConnectionTimedOut, lastAction: lastAction)
                    }
                }
            }
        case NotificationIdentifier.retryConnection.rawValue:
            if let lastActionRaw = userInfo["lastAction"] as? String,
                let lastAction = Action(rawValue: lastActionRaw) {
                print("Handle action: \(lastAction)")
                handleNotificationAction(lastAction)
            }
        default:
            print("Unknown action")
        }

        completionHandler()
    }
}



