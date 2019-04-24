//
//  SonicWallMobileConnect.swift
//  WebPunch
//
//  Created by Keaton Burleson on 4/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit
import NetworkExtension
import Alamofire

class SonicWall {
    // MARK: Static Properties
    static let shared = SonicWall()
    static var status: NEVPNStatus = .connecting {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name("sonicWallConnectionStatusChanged"), object: self.status)
        }
    }

    private lazy var alamoFireManager: SessionManager? = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 6
        configuration.timeoutIntervalForResource = 6
        let alamoFireManager = Alamofire.SessionManager(configuration: configuration)
        return alamoFireManager
    }()

    public static var useVPN: Bool {
        if UserDefaults(suiteName: "group.com.webpunch")!.hasKey(.useVPN) {
            return UserDefaults(suiteName: "group.com.webpunch")!.bool(forKey: "useVPN")
        } else {
            return false
        }
    }

    // MARK: Properties
    private let defaults = UserDefaults(suiteName: "group.com.webpunch")!
    public var isRefreshing = false
    private var readingAttempts = 0

    public var useVPN: Bool {
        return SonicWall.useVPN
    }

    public var status: NEVPNStatus {
        return SonicWall.status
    }

    private var canConnect: Bool = false {
        didSet {
            if self.canConnect == true {
                self.updateStatus(newStatus: .connected)
            } else {
                self.updateStatus(newStatus: .disconnected)
            }
        }
    }

    // MARK: Initializers
    private init() {
        checkForConnection()
    }

    // MARK: Functions
    public func connect() {
        if self.status != .connected {
            updateStatus(newStatus: .connecting)
            if let connectURL = buildURLWithCallback() {
                print("Connecting to SonicWall VPN")
                self.openURL(connectURL)
            } else {
                updateStatus(newStatus: .invalid)
            }
        } else {
            print("We're already connected")
        }
    }

    public func disconnect() {
        if self.status != .disconnected {
            updateStatus(newStatus: .disconnecting)
            if let disconnectURL = buildURLWithCallback(isConnecting: false) {
                print("Disconnecting to SonicWall VPN")
                self.openURL(disconnectURL)
            } else {
                updateStatus(newStatus: .invalid)
            }
        } else {
            print("We're already disconnected OR we haven't connected in the first place.")
        }
    }

    public func refreshStatus() {
        isRefreshing = true

        self.checkForConnection { (canConnect) in
            self.isRefreshing = false
            if canConnect == true {
                self.updateStatus(newStatus: .connected)
            } else {
                self.updateStatus(newStatus: .disconnected)
            }
        }
    }

    public func updateStatus(newStatus status: NEVPNStatus) {
        SonicWall.status = status
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "vpnStatusUpdated"), object: status)
        print("SonicWall VPN Connection Status Updated: \(status)")
    }

    // MARK: Helpers
    public func buildURLWithCallback(isConnecting: Bool = true) -> URL? {
        if let connectionName = defaults[.vpnConnectionName],
            let encodedConnectionName = connectionName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let ourURLScheme = UIApplication.urlSchemes?.first {

            let action = isConnecting ? "connect" : "disconnect"
            let callbackURLString = "\(ourURLScheme)://return?action=\(action)&status=$STATUS$"

            var returnedURL: URL? = nil


            if let (generatedCallbackURL, generatedCallbackString) = encodeURLString(callbackURLString),
                UIApplication.shared.canOpenURL(generatedCallbackURL) {

                if !isConnecting,
                    let validDisconnectURL = URL(string: "mobileconnect://\(action)?callbackurl=\(generatedCallbackString)") {
                    returnedURL = validDisconnectURL
                } else if let validConnectionURL = URL(string: "mobileconnect://\(action)?name=\(encodedConnectionName)&callbackurl=\(generatedCallbackString)") {
                    returnedURL = validConnectionURL
                }

                return returnedURL
            }
        }
        return nil
    }

    private func encodeURLString(_ urlString: String) -> (URL, String)? {
        if let firstPass = urlString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
            let secondPass = firstPass.replacingOccurrences(of: "&", with: "%26").replacingOccurrences(of: "$", with: "%24").replacingOccurrences(of: "=", with: "%3D")
            if let generatedURL = URL(string: urlString) {
                return (generatedURL, secondPass)
            }
        }
        return nil
    }

    private func openURL(_ url: URL) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    private func checkForConnection(completion: ((Bool) -> ())? = nil) {
        if let punchClockAddress = defaults.string(forKey: "ipAddress") {
            self.alamoFireManager!.request("http://\(punchClockAddress)").validate(statusCode: 200..<300).responseData { response in
                switch response.result {
                case .success:
                    print("Can connect to punch clock server")
                    self.canConnect = true
                case .failure:
                    print("Cannot connect to punch clock server")
                    self.canConnect = false
                }
                if let completionHandler = completion {
                    completionHandler(self.canConnect)
                }
            }
        }
    }
}

extension NEVPNStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connected:
            return "Connected"
        case .invalid:
            return "Invalid"
        case .connecting:
            return "Connecting"
        case .reasserting:
            return "Reasserting"
        case .disconnecting:
            return "Disconnecting"
            @unknown default:
            return "Unknown"
        }
    }
}
