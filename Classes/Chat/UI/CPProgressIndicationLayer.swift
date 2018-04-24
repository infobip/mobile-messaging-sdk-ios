//
//  CPProgressIndicationLayer.swift
//  Chatpay
//
//  Created by Andrey K. on 02.12.15.
//

import UIKit

class CPProgressIndicationLayer: CAShapeLayer {
	var aDuration: Double = 0

	override init(layer: Any) {
		super.init(layer: layer)
	}
	
	init(color: UIColor, width: CGFloat, duration: Double) {
		super.init()
		self.aDuration = duration
		self.path = customPath.cgPath
		self.strokeColor = color.cgColor
		self.fillColor = nil
		self.lineWidth = width
		self.lineJoin = kCALineJoinRound;
	}

	required init?(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}
	
	func startAnimation() {
		let a1 = CAKeyframeAnimation(keyPath: "strokeEnd")
		a1.duration = aDuration;
		a1.fillMode = kCAFillModeRemoved;
		a1.timeOffset = CACurrentMediaTime()
		a1.repeatCount = MAXFLOAT;
		a1.values = [0, 0.5, 1, 1, 1]
		self.add(a1, forKey:"strokeEnd")
		
		let a2 = CAKeyframeAnimation(keyPath: "strokeStart")
		a2.duration = aDuration;
		a2.fillMode = kCAFillModeRemoved;
		a2.timeOffset = CACurrentMediaTime()
		a2.repeatCount = MAXFLOAT;
		a2.values = [0, 0, 0, 0.5, 1]
		self.add(a2, forKey:"strokeStart")
	}

	override func layoutSublayers() {
		super.layoutSublayers()
		self.path = customPath.cgPath
	}
	
	func stopAnimation() {
		self.removeAllAnimations()
	}
	
	var customPath: UIBezierPath {
		let p = UIBezierPath()
		let center = CGPoint(x: self.bounds.size.width/2, y: self.bounds.size.height/2)
		let startAngle = CGFloat(-Double.pi/2)
		let endAngle = CGFloat(2 * CGFloat(Double.pi) + startAngle)
		p.addArc(withCenter: center, radius: (self.bounds.width/2)-self.lineWidth/2, startAngle: startAngle, endAngle: endAngle, clockwise: true)
		p.close()
		return p
	}
}
