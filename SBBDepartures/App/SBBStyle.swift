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

enum SBBStyle {
    static let red = Color(hex: SBBPalette.redHex)
    static let redDark = Color(hex: SBBPalette.redDarkHex)
    static let milk = Color(hex: SBBPalette.milkHex)
    static let cloud = Color(hex: SBBPalette.cloudHex)
    static let graphite = Color(hex: SBBPalette.graphiteHex)

}

struct SBBBrandHeader: View {
    var title: String
    var subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(SBBStyle.red)
                HStack(spacing: 3) {
                    Image(systemName: "arrow.left")
                    Text("SBB")
                        .font(.system(size: 17, weight: .black))
                    Image(systemName: "arrow.right")
                }
                .foregroundStyle(.white)
                .font(.system(size: 13, weight: .bold))
            }
            .frame(width: 86, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(SBBStyle.graphite)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

struct LineBadge: View {
    var text: String

    var body: some View {
        Text(text.isEmpty ? "?" : text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(SBBStyle.red, in: RoundedRectangle(cornerRadius: 3))
    }
}
