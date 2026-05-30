//
//  DisplayCards.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/31/23.
//

import SwiftUI

struct DisplayCards: View {
    // MARK: - PROPERTIES
    @Environment(\.colorScheme) var colorScheme
    let imageName: String
    let title: String
    let tintColor: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Spacer(minLength: 0)
            
            HStack {
                Spacer(minLength: 0)
                Image(systemName: imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundColor(.white)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        // Binding the gradient directly to the background guarantees no gray space leaks
        .background(
            LinearGradient(gradient: Gradient(colors: [tintColor.opacity(0.85),
                                                       tintColor.opacity(0.60)]),
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16.0, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    DisplayCards(imageName: "pencil", title: "QuickTest", tintColor: .red)
        .padding()
}
