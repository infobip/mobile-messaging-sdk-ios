import Foundation
import WebKit

class WebInAppMessageView: UIView {
    private static let shadowOpacity: Float = 0.7
    private static let shadowRadius: CGFloat = 4.0
    private static let shadowOffset = CGSize(width: 3, height: 3)
    
    let webView: WKWebView
    
    var cornerRadius: CGFloat {
        get {
            layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            webView.layer.cornerRadius = newValue
        }
    }
    
    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: webView.frame)
        addSubview(webView)
        
        // Important for constraints
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            webView.heightAnchor.constraint(equalTo: heightAnchor),
            webView.widthAnchor.constraint(equalTo: widthAnchor),
            webView.centerXAnchor.constraint(equalTo: centerXAnchor),
            webView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        // Important for corner radius
        webView.clipsToBounds = true
        
        // Shadow definition
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = WebInAppMessageView.shadowOffset
        layer.shadowOpacity = WebInAppMessageView.shadowOpacity
        layer.shadowRadius = WebInAppMessageView.shadowRadius
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
