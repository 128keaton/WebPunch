//
//  UISoundService.swift
//  WebPunch
//
//  Created by Keaton Burleson on 4/23/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit
import AudioToolbox

public class UISoundService {
    static let shared = UISoundService()

    // MARK: Sound URLS
    private let punchInSoundURL = URL(string: "/System/Library/Audio/UISounds/nano/MultiwayJoin.caf")
    private let punchOutSoundURL = URL(string: "/System/Library/Audio/UISounds/nano/MultiwayLeave.caf")

    // MARK: Sound IDs
    private var punchInSoundID: SystemSoundID? = nil
    private var punchOutSoundID: SystemSoundID? = nil


    private init() { }

    func playSoundForAction(_ action: Action) {
        switch action {
        case .punchIn:
            if let soundID = punchInSoundID {
                AudioServicesPlaySystemSound(soundID);
            } else {
                var newSoundID = SystemSoundID()
                AudioServicesCreateSystemSoundID(punchInSoundURL! as CFURL, &newSoundID)
                AudioServicesPlaySystemSound(newSoundID);
                punchInSoundID = newSoundID
            }
            break
        case .punchOut:
            if let soundID = punchOutSoundID {
                AudioServicesPlaySystemSound(soundID);
            } else {
                var newSoundID = SystemSoundID()
                AudioServicesCreateSystemSoundID(punchOutSoundURL! as CFURL, &newSoundID)
                AudioServicesPlaySystemSound(newSoundID);
                punchOutSoundID = newSoundID
            }
            break
        default:
            print("No sound for action \(action)")
            break
        }
    }
}
