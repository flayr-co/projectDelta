//
//  AnimatedActionButton.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 3/11/24.
//

// AnimatedActionButton.swift
import SwiftUI

struct AnimatedActionButton: View {
    @State private var isActivated: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.5)) {
                self.isActivated.toggle()
            }
        }) {
            Text(isActivated ? "LET'S GO!" : "READY?")
                .fontWeight(.bold)
                .font(.title)
                .foregroundStyle(isActivated ? .white : colorScheme == .dark ? .teal : .gray)
                .frame(maxWidth: .infinity, maxHeight: 50)
                .background(self.isActivated ? Color.HuluGreen : colorScheme == .dark ? .black : .white)
                .mask(RoundedRectangle(cornerRadius: 25))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.HuluGreen, lineWidth: 2)
                )
                .scaleEffect(isActivated ? 1.1 : 1.0)
        }
        .frame(width: 220)
        .padding(.horizontal)
    }
}

// Extension to hold the custom Hulu Green color
extension Color {
    static let HuluGreen = Color(red: 0/255, green: 186/255, blue: 124/255) // Hulu's brand green color
}

#Preview {
    AnimatedActionButton()
        .previewLayout(.sizeThatFits)
        .padding()
        .preferredColorScheme(.dark)
}

