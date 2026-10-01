import UIKit

/// Launcher styling from DESIGN.md. Player screens keep color restrained so the ad stays primary.
enum Theme {
    static let charcoal = UIColor(rgb: 0x2D2D2D)
    static let deepCharcoal = UIColor(rgb: 0x242222)
    static let fogGray = UIColor(rgb: 0xF6F6F6)
    static let mutedFog = UIColor(rgb: 0xE4E4E4)
    static let bloomPurple = UIColor(rgb: 0xBB6AEF)
    static let bloomPink = UIColor(rgb: 0xF948A1)
    static let bloomOrange = UIColor(rgb: 0xFC5D3D)
    static let bloomColors = [bloomPurple, bloomPink, bloomOrange]

    static func font(_ weight: UIFont.Weight, size: CGFloat, textStyle: UIFont.TextStyle) -> UIFont {
        let name: String
        switch weight {
        case .bold:
            name = "BeVietnamPro-Bold"
        case .medium:
            name = "BeVietnamPro-Medium"
        default:
            name = "BeVietnamPro-Regular"
        }
        let font = UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
    }

    static func styleNavigationBar(_ navigationBar: UINavigationBar) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = charcoal
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: fogGray,
            .font: font(.medium, size: 17, textStyle: .headline),
        ]
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = fogGray
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
