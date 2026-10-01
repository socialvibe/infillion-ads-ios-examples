import UIKit

/// Launcher: one card per integration example. Each example is self-contained in its own folder.
final class HomeViewController: UIViewController {
    private struct Example {
        let title: String
        let description: String
        let delivery: String
        let insertion: String
        let makeViewController: () -> UIViewController
    }

    private let examples: [Example] = [
        Example(
            title: "Plain / Manual CSAI",
            description: "Own the ad break yourself: pause content, run the interactive renderer, then skip or continue the pod.",
            delivery: "Simulated request",
            insertion: "Client-side",
            makeViewController: { ManualCsaiViewController() }
        ),
        Example(
            title: "Google IMA CSAI",
            description: "Let Google IMA request and sequence client-side ads while the app handles TrueX and IDVx placeholders.",
            delivery: "Google IMA",
            insertion: "Client-side",
            makeViewController: { ImaCsaiViewController() }
        ),
        Example(
            title: "Google IMA SSAI",
            description: "Play a Google DAI stream, coordinate stitched ad timing, and seek the stream when TrueX credit is earned.",
            delivery: "Google DAI",
            insertion: "Server-side",
            makeViewController: { ImaSsaiViewController() }
        ),
    ]

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.charcoal
        navigationItem.backButtonDisplayMode = .minimal

        let logo = UIImageView(image: UIImage(named: "InfillionLogo"))
        logo.contentMode = .scaleAspectFit
        logo.setContentHuggingPriority(.required, for: .vertical)
        logo.heightAnchor.constraint(equalToConstant: 36).isActive = true
        navigationItem.titleView = logo

        let heading = makeLabel("Interactive ads examples", font: Theme.font(.bold, size: 28, textStyle: .largeTitle), color: Theme.fogGray)
        let intro = makeLabel(
            "TrueX and IDVx ads rendered by TruexAdRenderer-iOS. Each example is self-contained: pick one and read it top to bottom.",
            font: Theme.font(.regular, size: 15, textStyle: .body),
            color: Theme.mutedFog
        )
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let footer = makeLabel(
            "App \(version) · TruexAdRenderer \(TRUEX_AD_RENDERER_VERSION)",
            font: Theme.font(.medium, size: 12, textStyle: .caption1),
            color: Theme.mutedFog.withAlphaComponent(0.6)
        )

        let stack = UIStackView(arrangedSubviews: [heading, intro])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(28, after: intro)
        for (index, example) in examples.enumerated() {
            stack.addArrangedSubview(makeCard(for: example, tag: index))
        }
        stack.addArrangedSubview(footer)
        stack.setCustomSpacing(16, after: stack.arrangedSubviews[stack.arrangedSubviews.count - 2])
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        let fullWidth = stack.widthAnchor.constraint(equalTo: frame.widthAnchor, constant: -40)
        fullWidth.priority = .required - 1
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            content.widthAnchor.constraint(equalTo: frame.widthAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            stack.centerXAnchor.constraint(equalTo: frame.centerXAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 640),
            fullWidth,
        ])
    }

    private func makeCard(for example: Example, tag: Int) -> UIView {
        let title = makeLabel(example.title, font: Theme.font(.bold, size: 20, textStyle: .title3), color: Theme.fogGray)
        let description = makeLabel(example.description, font: Theme.font(.regular, size: 15, textStyle: .body), color: Theme.mutedFog)
        let chips = UIStackView(arrangedSubviews: [makeChip(example.delivery), makeChip(example.insertion), UIView()])
        chips.spacing = 8

        let text = UIStackView(arrangedSubviews: [title, description, chips])
        text.axis = .vertical
        text.spacing = 8
        text.setCustomSpacing(14, after: description)
        text.isUserInteractionEnabled = false
        text.translatesAutoresizingMaskIntoConstraints = false

        let card = CardButton()
        card.tag = tag
        card.accessibilityLabel = example.title
        card.accessibilityHint = example.description
        card.addTarget(self, action: #selector(openExample(_:)), for: .touchUpInside)
        card.addSubview(text)
        NSLayoutConstraint.activate([
            text.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            text.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            text.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            text.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])
        return card
    }

    private func makeChip(_ text: String) -> UIView {
        let label = makeLabel(text, font: Theme.font(.medium, size: 12, textStyle: .caption1), color: Theme.fogGray)
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        let chip = UIView()
        chip.backgroundColor = Theme.charcoal
        chip.layer.cornerRadius = 12
        chip.layer.cornerCurve = .continuous
        chip.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: chip.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: chip.bottomAnchor, constant: -5),
            label.leadingAnchor.constraint(equalTo: chip.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: chip.trailingAnchor, constant: -10),
        ])
        return chip
    }

    private func makeLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    @objc private func openExample(_ sender: UIControl) {
        navigationController?.pushViewController(examples[sender.tag].makeViewController(), animated: true)
    }
}

/// Deep Charcoal card with a Bloom accent bar; scales down slightly while pressed.
private final class CardButton: UIControl {
    private let accent = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.deepCharcoal
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = Theme.fogGray.withAlphaComponent(0.08).cgColor
        clipsToBounds = true
        accent.colors = Theme.bloomColors.map(\.cgColor)
        accent.startPoint = CGPoint(x: 0, y: 0.5)
        accent.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(accent)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        accent.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 4)
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            }
        }
    }
}
