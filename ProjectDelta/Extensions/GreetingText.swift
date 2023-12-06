//
//  GreetingText.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/26/23.
//

import Foundation
import SwiftUI

// MARK: - EXTENSION FOR THE REUSABLE STYLING COMPONENT ON THAT TEXT???

struct GreetingTextModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 20, weight: .medium, design: .default))
            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
            .padding([.leading, .trailing], 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
    }
}

extension Text {
    func greetingStyle() -> some View {
        self.modifier(GreetingTextModifier())
    }
}
