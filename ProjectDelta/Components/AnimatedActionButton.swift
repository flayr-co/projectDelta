//
//  AnimatedActionButton.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 3/11/24.
//

import SwiftUI

struct AnimatedActionButton: View {
    @State private var isActivated: Bool = false
    @State private var isPulsing: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    // Dynamically match the app's established theme
    var themeColor: Color {
        colorScheme == .dark ? .teal : .blue
    }

    var body: some View {
        Button(action: {
            #if os(iOS)
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            #endif
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                self.isActivated.toggle()
            }
        }) {
            HStack(spacing: 8) {
                Text(isActivated ? "Let's Go!" : "Ready?")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Image(systemName: isActivated ? "checkmark.seal.fill" : "sparkles")
                    .font(.headline)
                    .rotationEffect(.degrees(isActivated ? 360 : 0))
            }
            .foregroundColor(.white)
            .frame(maxWidth: 320, minHeight: 52)
            .background(
                ZStack {
                    if isActivated {
                        LinearGradient(
                            colors: [Color.green, Color.mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient(
                            colors: [themeColor, themeColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(
                color: isActivated ? Color.green.opacity(0.4) : themeColor.opacity(0.4),
                radius: isActivated ? 8 : 6,
                y: 4
            )
            .scaleEffect(isActivated ? 1.05 : (isPulsing ? 1.02 : 1.0))
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

#Preview {
    AnimatedActionButton()
        .previewLayout(.sizeThatFits)
        .padding()
        .preferredColorScheme(.dark)
}
