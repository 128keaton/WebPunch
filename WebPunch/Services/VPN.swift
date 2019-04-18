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
    
    private (set) public var isConnected = false

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
            vpnConnection.authenticationMethod = .sharedSecret
            vpnConnection.sharedSecretReference = keyChain.load(key: "vpnSharedSecret")
            vpnConnection.disconnectOnSleep = false

            self.vpnManager.protocolConfiguration = vpnConnection
            self.vpnManager.isEnabled = true
            self.vpnManager.saveToPreferences(completionHandler: { (error) -> Void in
                if let anError = error {
                    print("Save Error: ", anError)
                }
                do {
                    try NEVPNManager.shared().connection.startVPNTunnel()
                } catch {
                    print("Fire Up Error: ", error)
                    return
                }
                 self.isConnected = true
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
                    return
                }
                self.isConnected = true
            }
        }
    }


    public func connectVPN() {
        self.vpnManager.loadFromPreferences { (_) in
            self.vpnManager.loadFromPreferences(completionHandler: self.vpnLoadHandler)
        }
    }

    public func disconnectVPN() -> Void {
        vpnManager.connection.stopVPNTunnel()
    }
}
