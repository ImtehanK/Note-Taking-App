import SwiftUI

extension NoteColor {
    var background: Color {
        switch self {
        case .terracotta: return Color(red: 0.91, green: 0.72, blue: 0.63)
        case .sage:       return Color(red: 0.75, green: 0.83, blue: 0.73)
        case .sand:       return Color(red: 0.93, green: 0.88, blue: 0.75)
        case .clay:       return Color(red: 0.85, green: 0.70, blue: 0.58)
        case .moss:       return Color(red: 0.65, green: 0.75, blue: 0.63)
        case .dusk:       return Color(red: 0.80, green: 0.76, blue: 0.88)
        }
    }

    var foreground: Color {
        // All earthy tones work well with a dark brown/charcoal text
        return Color(red: 0.20, green: 0.16, blue: 0.13)
    }

    var secondaryForeground: Color {
        return Color(red: 0.20, green: 0.16, blue: 0.13).opacity(0.55)
    }

    var divider: Color {
        return Color(red: 0.20, green: 0.16, blue: 0.13).opacity(0.12)
    }
}

