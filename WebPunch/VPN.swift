//
//  VPNManager.swift
//  WebPunch
//
//  Created by Keaton Burleson on 4/17/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import NetworkExtension

class VPN {
    let vpnManager = NEVPNManager.shared();

    private var vpnLoadHandler: (Error?) -> Void { return
        { (error: Error?) in
            if ((error) != nil) {
                print("Could not load VPN Configurations")
                return;
            }
            let Defaults = UserDefaults(suiteName: "group.com.webpunch")!
            let keyChain = KeychainService()
            let vpnConnection = NEVPNProtocolIPSec()

            vpnConnection.username = Defaults[.vpnUsername]
            vpnConnection.serverAddress = Defaults[.vpnAddress]
            vpnConnection.passwordReference = keyChain.load(key: "vpnPassword")

            vpnConnection.disconnectOnSleep = false

            self.vpnManager.protocolConfiguration = vpnConnection
            self.vpnManager.isEnabled = true
            self.vpnManager.saveToPreferences(completionHandler: { (error) -> Void in
                if let _ = error {
                    print("Save Error: ", error)
                }
                do {
                    try NEVPNManager.shared().connection.startVPNTunnel()
                } catch {
                    print("Fire Up Error: ", error)
                }
            })
        }
    }

    private var vpnSaveHandler: (Error?) -> Void { return
        { (error: Error?) in
            if (error != nil) {
                print("Could not save VPN Configurations")
                return
            } else {
                do {
                    try self.vpnManager.connection.startVPNTunnel()
                } catch let error {
                    print("Error starting VPN Connection \(error.localizedDescription)");
                }
            }
        }
    }

    public func connectVPN() {
        self.testConnect()
    }

    public func testConnect() {
        self.vpnManager.loadFromPreferences { (error) in
            if let anError = error {
                print("Error loading: \(anError)")
                let Defaults = UserDefaults(suiteName: "group.com.webpunch")!
                let keyChain = KeychainService()
                let vpnConnection = NEVPNProtocolIPSec()

                vpnConnection.username = Defaults[.vpnUsername]
                vpnConnection.serverAddress = Defaults[.vpnAddress]
                vpnConnection.passwordReference = keyChain.load(key: "vpnPassword")

                vpnConnection.disconnectOnSleep = false

                self.vpnManager.protocolConfiguration = vpnConnection
                self.vpnManager.isEnabled = true
                self.vpnManager.saveToPreferences(completionHandler: { (error) -> Void in
                    if let anError = error {
                        print("Save Error: ", anError)
                        return
                    }

                    do {
                        try self.vpnManager.connection.startVPNTunnel()
                    } catch {
                        print("Fire Up Error: ", error)
                    }
                })
            } else {
                do {
                    try self.vpnManager.connection.startVPNTunnel()
                } catch {
                    print("Fire Up Error: ", error)
                }
            }
        }
    }

    public func disconnectVPN() -> Void {
        vpnManager.connection.stopVPNTunnel()
    }
}
