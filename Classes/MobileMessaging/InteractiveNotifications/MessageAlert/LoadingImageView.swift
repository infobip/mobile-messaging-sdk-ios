//
//  LoadingImageView.swift
//  MobileMessaging
//
//  Created by okoroleva on 14.09.17.
//

import UIKit

class LoadingImageView: UIView {
    @IBOutlet weak var contentImageView: AnimatedImageView!
	@IBOutlet weak var errorLabel: UILabel!
    
    var view: UIView!
    
    func xibSetup() {
        view = loadViewFromNib()
        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(view)
		contentImageView.kf.indicatorType = .activity
    }
    
    func loadViewFromNib() -> UIView {
        let nib = UINib(nibName: "LoadingImageView", bundle: MobileMessaging.resourceBundle)
        let view = nib.instantiate(withOwner: self, options: nil)[0] as! UIView
        
        return view
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        xibSetup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        xibSetup()
    }
	
	func loadImage(withURL url: URL, width: CGFloat, height: CGFloat, completion: @escaping (_ imageObject: AnyObject?, Error?) -> Void) {

		self.contentImageView?.kf.setImage(with: url, completionHandler: {
			(image, error, cacheType, imageUrl) in
			
			self.updateContentMode(image: image, width: width, height: height)
			self.showErrorIfNeeded(error: error)
			completion(image, error)
		})
	}
	
	func showErrorIfNeeded(error: Error?) {
		if error != nil {
            DispatchQueue.main.async {
                self.errorLabel?.text = MMInteractiveMessageAlertSettings.errorPlaceholderText
            }
		}
	}
	
	func imageSize(width: CGFloat, height: CGFloat) -> CGSize? {
		if let image = self.contentImageView.image {
			return CGSizeAspectFit(aspectRatio: image.size, boundingSize: CGSize(width: width, height: height))
		}
		return nil
	}
	
	//Private
	private func updateContentMode(image: UIImage?, width: CGFloat, height: CGFloat) {
		if let image = image {
			self.contentImageView?.contentMode = image.size.width < width && image.size.height < height ? .center : .scaleAspectFit
		}
	}
}

func CGSizeAspectFit(aspectRatio: CGSize, boundingSize: CGSize) -> CGSize {
	let mW = boundingSize.width / aspectRatio.width;
	let mH = boundingSize.height / aspectRatio.height;
	var resultSize: CGSize = boundingSize
	if mH < mW  {
		resultSize.width = resultSize.height / aspectRatio.height * aspectRatio.width
	}
	else if  mW < mH  {
		resultSize.height = resultSize.width / aspectRatio.width * aspectRatio.height
	}
	return resultSize;
}
