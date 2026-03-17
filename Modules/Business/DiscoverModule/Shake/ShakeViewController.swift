import UIKit

public class ShakeViewController: UIViewController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "摇一摇"

        let label = UILabel()
        label.text = "摇一摇"
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
