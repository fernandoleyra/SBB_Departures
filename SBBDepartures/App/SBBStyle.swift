import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(cleaned, radix: 16) ?? 0
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

enum SBBPalette {
    static let redHex = "#EB0000"
    static let redDarkHex = "#C60018"
    static let milkHex = "#F6F6F6"
    static let cloudHex = "#E5E5E5"
    static let metalHex = "#DCDCDC"
    static let graphiteHex = "#2D2D2D"
    static let blueHex = "#1F6AA5"
    static let greenHex = "#2E7D32"
    static let violetHex = "#7B3FA1"
    static let orangeHex = "#D86B00"
    static let tealHex = "#006E7F"
}

enum SBBStyle {
    static let red      = Color(hex: SBBPalette.redHex)
    static let redDark  = Color(hex: SBBPalette.redDarkHex)
    static let milk     = Color(hex: SBBPalette.milkHex)
    static let cloud    = Color(hex: SBBPalette.cloudHex)
    static let graphite = Color(hex: SBBPalette.graphiteHex)
    static let blue     = Color(hex: SBBPalette.blueHex)
    static let green    = Color(hex: SBBPalette.greenHex)
    static let violet   = Color(hex: SBBPalette.violetHex)
    static let teal     = Color(hex: SBBPalette.tealHex)

    // Returns the SBB brand color for a transport category string.
    // Accepts raw category ("IC"), combined display ("IC 5"), or lowercase ("ic 5").
    // STR/NFT/T are checked before S to prevent S-Bahn false match.
    // NFB is checked before B for the same reason.
    static func badgeColor(for category: String) -> Color {
        let c = category.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch c {
        case let x where x.hasPrefix("IC") || x.hasPrefix("IR") || x.hasPrefix("EC") || x.hasPrefix("EN"):
            return red
        case let x where x.hasPrefix("RE") || x.hasPrefix("RB"):
            return redDark
        case let x where x.hasPrefix("STR") || x.hasPrefix("NFT") || x.hasPrefix("T"):
            return violet
        case let x where x.hasPrefix("S"):
            return green
        case let x where x.hasPrefix("BAT") || x.hasPrefix("CGN"):
            return teal
        case let x where x.hasPrefix("NFB") || x.hasPrefix("B"):
            return blue
        case let x where x.hasPrefix("N"):
            return graphite
        default:
            return graphite
        }
    }
}

// LineBadge now accepts an explicit color; defaults to SBBStyle.red so
// existing call sites without a color argument continue to compile.
struct LineBadge: View {
    var text: String
    var color: Color = SBBStyle.red

    var body: some View {
        Text(text.isEmpty ? "?" : text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color, in: RoundedRectangle(cornerRadius: 3))
    }
}

