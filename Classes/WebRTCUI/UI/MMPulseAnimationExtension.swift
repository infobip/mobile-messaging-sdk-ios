//
//  MMPulseAnimationExtension.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 02/09/2021.
//  Copyright © 2021 Infobip Ltd. All rights reserved.
//

import UIKit
#if WEBRTCUI_ENABLED
extension MMCallController {
    func createPulse() {
        self.pulse.layer.cornerRadius = self.pulse.frame.height / 2
        for _ in 0...2 {
            let circularPath = UIBezierPath(arcCenter: .zero, 
                                            radius: self.pulse.frame.size.width*2, 
                                            startAngle: 0, 
                                            endAngle: 2 * .pi , 
                                            clockwise: true)
            let pulsatingLayer = CAShapeLayer()
            pulsatingLayer.path = circularPath.cgPath
            pulsatingLayer.lineWidth = 5
            pulsatingLayer.fillColor = UIColor.clear.cgColor
            pulsatingLayer.lineCap = CAShapeLayerLineCap.round
            pulsatingLayer.position = CGPoint(x: self.pulse.frame.size.width / 2.0, 
                                              y: self.pulse.frame.size.width / 2.0)
            self.pulse.layer.addSublayer(pulsatingLayer)
            self.pulseLayers.append(pulsatingLayer)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
            self.animatePulsatingLayerAt(index: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                self.animatePulsatingLayerAt(index: 1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                    self.animatePulsatingLayerAt(index: 2)
                })
            })
        })
    }
    
    func stopPulse() {
        DispatchQueue.main.async {
            self.pulse.stopAnimating()
            self.pulseLayers.forEach { layer in
                layer.removeAllAnimations()
            }
        }
    }
    
    private func animatePulsatingLayerAt(index: Int) {
        self.pulseLayers[index].strokeColor = MMWebRTCSettings.sharedInstance.pulseStrokeColor.cgColor
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.0
        scaleAnimation.toValue = 0.9
        
        let opacityAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        opacityAnimation.fromValue = 0.9
        opacityAnimation.toValue = 0.0
        
        let groupAnimation = CAAnimationGroup()
        groupAnimation.animations = [scaleAnimation, opacityAnimation]
        groupAnimation.duration = 2.0
        groupAnimation.repeatCount = .greatestFiniteMagnitude
        groupAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        
        self.pulseLayers[index].add(groupAnimation, forKey: "groupanimation")
    }
}
#endif
