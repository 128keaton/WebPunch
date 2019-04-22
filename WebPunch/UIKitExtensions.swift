//
//  UIKitExtensions.swift
//  WebPunch
//
//  Created by Keaton Burleson on 4/22/19.
//  Copyright © 2019 Keaton Burleson. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
    public func displayAlert(bodyText: String, title: String) {
        #if DEBUG
            print("\(title): \(bodyText)")
        #else
            let alertController = UIAlertController(title: title, message: bodyText, preferredStyle: .alert)
            let dismissButton = UIAlertAction(title: "Ok", style: .default) { (action) in
                alertController.dismiss(animated: true, completion: nil)
            }
            alertController.addAction(dismissButton)
            self.present(alertController, animated: true, completion: nil)
        #endif
    }
}
