//
//  IntentHandler.swift
//  PunchIntent
//
//  Created by Keaton Burleson on 9/19/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import Intents
import SwiftyUserDefaults

class IntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        switch intent {
        case is PunchInIntent:
            return PunchInHandler()
        case is PunchOutIntent:
            return PunchOutHandler()
        case is PunchStatusIntent:
            return PunchStatusHandler()
        default:
            return self
        }
    }

}

class PunchInHandler: NSObject, PunchInIntentHandling {
    let punchInterface = PunchInterface()
    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!

    func handle(intent: PunchInIntent, completion: @escaping (PunchInIntentResponse) -> Void) {
        if(Defaults[.punchedIn] == nil || Defaults[.punchedIn] == false) {
            punchInterface.canConnect { (canConnect, statusCode) in
                if (canConnect) {
                    self.punchInterface.login { (success) in
                        if(success) {
                            self.punchInterface.punchIn { (success) in
                                if(success) {
                                    completion(PunchInIntentResponse(code: .success, userActivity: nil))
                                } else {
                                    completion(PunchInIntentResponse(code: .failure, userActivity: nil))
                                }
                            }
                        } else {
                            completion(PunchInIntentResponse(code: .failure, userActivity: nil))
                        }
                    }
                } else {
                    if (statusCode == 1) {
                        completion(PunchInIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
                    } else {
                        completion(PunchInIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
                    }
                }
            }
        } else {
            completion(PunchInIntentResponse(code: .alreadyPunchedIn, userActivity: nil))
        }
    }
}

class PunchOutHandler: NSObject, PunchOutIntentHandling {
    let punchInterface = PunchInterface()
    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!

    func handle(intent: PunchOutIntent, completion: @escaping (PunchOutIntentResponse) -> Void) {
        if(Defaults[.punchedIn] == nil || Defaults[.punchedIn] == true) {
            punchInterface.canConnect { (canConnect, statusCode) in
                if(canConnect) {
                    self.punchInterface.login { (success) in
                        if(success) {
                            self.punchInterface.punchOut { (success) in
                                if(success) {
                                    completion(PunchOutIntentResponse(code: .success, userActivity: nil))
                                } else {
                                    completion(PunchOutIntentResponse(code: .failure, userActivity: nil))
                                }
                            }
                        } else {
                            completion(PunchOutIntentResponse(code: .failure, userActivity: nil))
                        }
                    }
                } else {
                    if (statusCode == 1) {
                        completion(PunchOutIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
                    } else {
                        completion(PunchOutIntentResponse(code: .failureRequiringAppLaunch, userActivity: nil))
                    }
                }
            }
        } else {
            completion(PunchOutIntentResponse(code: .alreadyPunchedOut, userActivity: nil))
        }
    }
}

class PunchStatusHandler: NSObject, PunchStatusIntentHandling {
    var Defaults = UserDefaults(suiteName: "group.com.webpunch")!

    func handle(intent: PunchStatusIntent, completion: @escaping (PunchStatusIntentResponse) -> Void) {
        if(Defaults[.punchedIn] != nil) {
            if(Defaults[.punchedIn] == true) {
                completion(PunchStatusIntentResponse(code: .isPunchedIn, userActivity: nil))
            } else {
                completion(PunchStatusIntentResponse(code: .isNotPunchedIn, userActivity: nil))
            }
        } else {
            completion(PunchStatusIntentResponse(code: .failure, userActivity: nil))
        }
    }
}

