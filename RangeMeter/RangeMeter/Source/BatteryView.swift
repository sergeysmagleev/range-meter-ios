//
//  BatteryView.swift
//  RangeMeter
//
//  Created by Sergey Smagleev on 25.05.18.
//  Copyright © 2018 Sergey Smagleev. All rights reserved.
//

import UIKit
import CoreGraphics

class BatteryView: UIView {
    
    var batteryLife: Double = 100.0
    
    func changeBatteryLife(_ batteryLife: Double) {
        self.batteryLife = min(max(0.0, batteryLife), 100.0)
        self.setNeedsDisplay()
    }
    
    private func batteryColor(batteryLife: Double) -> UIColor {
        if batteryLife > 80.0 {
            return UIColor.green
        }
        if batteryLife > 50.0 {
            return UIColor.yellow
        }
        if batteryLife > 20.0 {
            return UIColor.orange
        }
        return UIColor.red
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        context.setFillColor(UIColor.white.cgColor)
        context.fill(self.bounds)
        let color = batteryColor(batteryLife: batteryLife)
        var chargeRect = self.bounds.insetBy(dx: 10.0, dy: 10.0)
        let width = chargeRect.width * CGFloat(batteryLife / 100)
        let newSize = CGSize(width: CGFloat(width), height: chargeRect.height)
        chargeRect.size = newSize
        context.setFillColor(color.cgColor)
        context.fill(chargeRect)
    }
}
