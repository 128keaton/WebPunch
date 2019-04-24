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

extension UIApplication {
    public static var urlSchemes: [String]? {
        guard let urlTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: AnyObject]] else {
            return nil
        }
        var result = [String]()
        for urlType in urlTypes {
            if let schemes = urlType["CFBundleURLSchemes"] as? [String] {
                result += schemes
            }
        }
        return result.isEmpty ? nil : result
    }
}

public extension UIButton {
    enum Mode {
        case standard
        case loadingIndicator
    }

    func pulsate() {
        let pulse = CASpringAnimation(keyPath: "transform.scale")
        pulse.duration = 0.2
        pulse.fromValue = 0.95
        pulse.toValue = 1.0
        pulse.autoreverses = true
        pulse.repeatCount = 2
        pulse.initialVelocity = 0.5
        pulse.damping = 1.0

        layer.add(pulse, forKey: "pulse")
    }

    func flash() {
        let flash = CABasicAnimation(keyPath: "opacity")
        flash.duration = 0.2
        flash.fromValue = 1
        flash.toValue = 0.1
        flash.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        flash.autoreverses = true
        flash.repeatCount = 3

        layer.add(flash, forKey: nil)
    }

    func shake() {
        let shake = CABasicAnimation(keyPath: "position")
        shake.duration = 0.05
        shake.repeatCount = 2
        shake.autoreverses = true

        let fromPoint = CGPoint(x: center.x - 5, y: center.y)
        let fromValue = NSValue(cgPoint: fromPoint)

        let toPoint = CGPoint(x: center.x + 5, y: center.y)
        let toValue = NSValue(cgPoint: toPoint)

        shake.fromValue = fromValue
        shake.toValue = toValue

        layer.add(shake, forKey: "position")
    }


    private func getLoadingAnimation() -> CABasicAnimation {
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0.0
        rotateAnimation.toValue = CGFloat(.pi * 2.0)
        rotateAnimation.duration = 2.0
        rotateAnimation.repeatCount = .greatestFiniteMagnitude

        return rotateAnimation
    }

    private func setupLoadingIndicatorMode() {
        UIView.animate(withDuration: 0.5) {
            self.tintColor = UIColor(hue: 0.5472, saturation: 1, brightness: 0.93, alpha: 1.0)
        }
    }

    func startSpinning() {
        self.layer.add(getLoadingAnimation(), forKey: "loadingAnimation")
    }

    func stopSpinning() {
        self.layer.removeAnimation(forKey: "loadingAnimation")
    }

    func updateSpinningStatus(hasPartiallyLoaded: Bool = true){
        var newTintColor = UIColor(hue: 0.5472, saturation: 1, brightness: 0.93, alpha: 1.0)
        
        if hasPartiallyLoaded {
            newTintColor = UIColor(displayP3Red: 0.2431, green: 0.8627, blue: 0.3804, alpha: 1.0)
        }
        
        UIView.animate(withDuration: 0.5) {
            self.tintColor = newTintColor
        }
    }
    
    func contentLoaded(successfully: Bool = true) {
        self.stopSpinning()

        var newTintColor = UIColor(displayP3Red: 0.8667, green: 0.0784, blue: 0.2902, alpha: 1.0)
        
        if successfully {
            newTintColor = UIColor(displayP3Red: 0.2431, green: 0.8627, blue: 0.3804, alpha: 1.0)
        }

        UIView.animate(withDuration: 0.5) {
            self.tintColor = newTintColor
        }
    }
    
    func reset(darkContent: Bool = true){
        var newTintColor = UIColor(hue: 0.5472, saturation: 1, brightness: 0.93, alpha: 1.0)
        
        if darkContent {
            newTintColor = UIColor.white
        }
        
        UIView.animate(withDuration: 0.5) {
            self.tintColor = newTintColor
        }
    }

    func setMode(mode aMode: Mode) {
        switch aMode {
        case .loadingIndicator:
            self.setupLoadingIndicatorMode()
        default:
            break
        }
    }
}
