//
//  TextStylingUtility.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/9/24.
//

import SwiftUI

struct TextStylingUtility {
    static func styledText(from markupText: String) -> some View {
        var views: [AnyView] = []
        var isBold = false
        var isItalic = false
        var currentColor: Color = .primary
        var redTextActive = false // Manage red text activation specifically

        let regex = try! NSRegularExpression(pattern: "(\\*b|\\*i|\\*r|\\*g|\\$\\$.*?\\$\\$)")
        let range = NSRange(markupText.startIndex..<markupText.endIndex, in: markupText)
        let components = regex.splitTextAndSeparator(markupText, range: range)

        for component in components {
            if component.separator.hasPrefix("$$") && component.separator.hasSuffix("$$") {
                let latexContent = component.separator.dropFirst(2).dropLast(2)
                views.append(AnyView(
                    LatexView(latex: "$\(latexContent)$")
                        .frame(height: 30)
                        .padding(.vertical, 4)
                ))
            } else {
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

                views.append(AnyView(currentText))
            }

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

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<views.count, id: \.self) { index in
                views[index]
            }
        }
    }
}

private extension NSRegularExpression {
    func splitTextAndSeparator(_ text: String, range: NSRange) -> [(text: String, separator: String)] {
        var components: [(text: String, separator: String)] = []
        var lastEndIndex = 0

        let matches = self.matches(in: text, options: [], range: range)
        for match in matches {
            let separatorRange = match.range(at: 0)
            let separator = (text as NSString).substring(with: separatorRange)
            let textRange = NSRange(location: lastEndIndex, length: separatorRange.location - lastEndIndex)
            let componentText = (text as NSString).substring(with: textRange)
            components.append((text: componentText, separator: separator))
            lastEndIndex = separatorRange.location + separatorRange.length
        }

        if lastEndIndex < text.count {
            let remainingTextRange = NSRange(location: lastEndIndex, length: text.count - lastEndIndex)
            let remainingText = (text as NSString).substring(with: remainingTextRange)
            components.append((text: remainingText, separator: ""))
        }

        return components
    }
}

//#Preview {
//    TextStylingUtility()
//}
