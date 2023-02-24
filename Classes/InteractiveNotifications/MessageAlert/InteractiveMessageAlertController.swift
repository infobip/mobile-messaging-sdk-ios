import Foundation

protocol InteractiveMessageAlertController: UIViewController {
    var dismissHandler: (() -> Void)? { get set }
}
