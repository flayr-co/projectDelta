//
//  Color+Platform.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 6/12/26.
//

//
//  Color+Platform.swift
//  ProjectDelta
//

import SwiftUI

#if os(macOS)
import AppKit
extension Color {
    static var platformSystemBackground: Color { Color(nsColor: .windowBackgroundColor) }
    static var platformSystemGroupedBackground: Color { Color(nsColor: .windowBackgroundColor) }
    static var platformSecondarySystemGroupedBackground: Color { Color(nsColor: .controlBackgroundColor) }
    static var platformSecondarySystemBackground: Color { Color(nsColor: .controlBackgroundColor) }
    static var platformTertiarySystemBackground: Color { Color(nsColor: .controlBackgroundColor) }
}
#else
import UIKit
extension Color {
    static var platformSystemBackground: Color { Color(uiColor: .systemBackground) }
    static var platformSystemGroupedBackground: Color { Color(uiColor: .systemGroupedBackground) }
    static var platformSecondarySystemGroupedBackground: Color { Color(uiColor: .secondarySystemGroupedBackground) }
    static var platformSecondarySystemBackground: Color { Color(uiColor: .secondarySystemBackground) }
    static var platformTertiarySystemBackground: Color { Color(uiColor: .tertiarySystemBackground) }
}
#endif
