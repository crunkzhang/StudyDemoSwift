import UIKit

open class BaseViewController: UIViewController {

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.post(name: .baseVCWillAppear, object: self)
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.post(name: .baseVCDidAppear, object: self)
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.post(name: .baseVCWillDisappear, object: self)
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.post(name: .baseVCDidDisappear, object: self)
    }
}

public extension Notification.Name {
    static let baseVCWillAppear = Notification.Name("BaseVCWillAppear")
    static let baseVCDidAppear = Notification.Name("BaseVCDidAppear")
    static let baseVCWillDisappear = Notification.Name("BaseVCWillDisappear")
    static let baseVCDidDisappear = Notification.Name("BaseVCDidDisappear")
}
