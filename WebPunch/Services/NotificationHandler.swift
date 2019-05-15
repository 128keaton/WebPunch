//
//  NotificationHandler.swift
//  WebPunch
//
//  Created by Keaton Burleson on 5/2/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UserNotifications
import UIKit

class NotificationHandler: NSObject {
    public static let shared = NotificationHandler()

    private var canUseNotifications = false
    private var storage = Storage()
    private var Defaults = UserDefaults(suiteName: "group.com.webpunch")!

    private let notificationCenter = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        
        canUseNotifications = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(scheduleHoursNotification(notification:)), name: PunchModel.didPunchIn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(removeHoursNotification(notification:)), name: PunchModel.didPunchOut, object: nil)
    }

    
    override var description: String {
        return "NotificationHandler: \(canUseNotifications)"
    }
    
    @objc func scheduleHoursNotification(notification: Notification) {
        if let notificationID = notification.object as? String, canUseNotifications == true {
            scheduleHoursNotification(forPunchID: notificationID)
        } else if canUseNotifications == false {
            print("User has declined notifications")
        }
    }

    @objc func removeHoursNotification(notification: Notification) {
        if let notificationID = notification.object as? String, canUseNotifications == true {
            removeHoursNotification(forPunchID: notificationID)
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

    func removeHoursNotification(forPunchID punchID: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [punchID])
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

    public func handleNotificationAction(_ action: Action) {
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

extension NotificationHandler: UNUserNotificationCenterDelegate {
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
