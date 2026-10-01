import UIKit

/// Compact status surface for player screens: content, ad request, linear ad, interactive ad, recovery, or error.
final class StatusView: UIView {
    private let label = UILabel()

    var text: String? {
        get { label.text }
        set {
            label.text = newValue
            if let newValue {
                exampleLog(newValue)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.deepCharcoal.withAlphaComponent(0.85)
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        isUserInteractionEnabled = false

        label.font = Theme.font(.medium, size: 13, textStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = Theme.fogGray
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Pins the status surface to the upper-left safe area of `viewController`.
    func install(in viewController: UIViewController) {
        translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(self)
        let guide = viewController.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -16),
        ])
    }
}

/// Logs to the unified log, so messages show up in Console and `log stream` as well as in Xcode.
func exampleLog(_ message: String) {
    NSLog("[InfillionAdsExamples] %@", message)
}
