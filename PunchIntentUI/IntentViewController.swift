//
//  IntentViewController.swift
//  PunchIntentUI
//
//  Created by Keaton Burleson on 9/19/18.
//  Copyright © 2018 Keaton Burleson. All rights reserved.
//

import IntentsUI

// As an example, this extension's Info.plist has been configured to handle interactions for INSendMessageIntent.
// You will want to replace this or add other intents as appropriate.
// The intents whose interactions you wish to handle must be declared in the extension's Info.plist.

// You can test this example integration by saying things to Siri like:
// "Send a message using <myApp>"

class IntentViewController: UIViewController, INUIHostedViewControlling {
    @IBOutlet weak var confirmLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    // MARK: - INUIHostedViewControlling

    // Prepare your view controller for the interaction to handle.
    func configureView(for parameters: Set<INParameter>, of interaction: INInteraction, interactiveBehavior: INUIInteractiveBehavior, context: INUIHostedViewContext, completion: @escaping (Bool, Set<INParameter>, CGSize) -> Void) {
        switch interaction.intent {
        case is PunchOutIntent:
            confirmLabel?.text = "Are you sure you want to punch out?"
            break
        case is PunchInIntent:
            confirmLabel?.text = "Are you sure you want to punch in?"
            break
        default:
            confirmLabel?.text = "Are you sure?"
        }

        completion(true, parameters, self.desiredSize)
    }

    var desiredSize: CGSize {
        return CGSize(width: 0, height: 100)
    }

}
