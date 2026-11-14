import SwiftUI
import UIKit

enum Haptics {
    static var enabled = true
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

enum Theme {
    static let bg = Color(red: 0.03, green: 0.04, blue: 0.07)
    static let panel = Color(red: 0.06, green: 0.08, blue: 0.13)
    static let accent = Color(red: 0.12, green: 0.52, blue: 1.0)
    static let off = Color(white: 0.17)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.62)
    static let espVisible = Color(red: 0.25, green: 0.85, blue: 1.0)
    static let espHidden = Color(red: 0.40, green: 0.50, blue: 0.72)
    static let espTarget = Color.white

    static func configureAppearance() {
        let seg = UISegmentedControl.appearance()
        seg.selectedSegmentTintColor = UIColor(accent)
        seg.backgroundColor = UIColor(white: 0.14, alpha: 1)
        seg.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        seg.setTitleTextAttributes([.foregroundColor: UIColor(white: 0.7, alpha: 1)], for: .normal)
    }
}
