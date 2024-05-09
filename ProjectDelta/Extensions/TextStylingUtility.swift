//
//  TextStylingUtility.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/9/24.
//

import SwiftUI

struct TextStylingUtility {
    static func styledText(from markupText: String) -> Text {
        var finalText = Text("")
        var isBold = false
        var isItalic = false
        var currentColor: Color = .primary
        var redTextActive = false // Manage red text activation specifically

        let regex = try! NSRegularExpression(pattern: "(\\*b|\\*i|\\*r|\\*g)")
        let range = NSRange(markupText.startIndex..<markupText.endIndex, in: markupText)
        let components = regex.split(markupText, range: range)

        for component in components {
            var currentText = Text(component.text)

            if isBold {
                currentText = currentText.bold()
            }
            if isItalic {
                currentText = currentText.italic()
            }
            if redTextActive {
                currentText = currentText.foregroundColor(.red)
            } else {
                currentText = currentText.foregroundColor(currentColor)
            }

            finalText = finalText + currentText

            switch component.separator {
            case "*b":
                isBold.toggle()
            case "*i":
                isItalic.toggle()
            case "*r":
                redTextActive.toggle() // Toggle the activation state of red text
            case "*g":
                if redTextActive {
                    redTextActive = false // Ensure that red text is turned off before turning green on
                }
                currentColor = .green
            default:
                break
            }
        }

        return finalText
    }
}

//#Preview {
//    TextStylingUtility()
//}
