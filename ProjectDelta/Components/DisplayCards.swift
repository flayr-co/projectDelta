//
//  DisplayCards.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/31/23.
//

// DisplayCards.swift
import SwiftUI

struct DisplayCards: View {
    // MARK: - PROPERTIES
    @Environment(\.colorScheme) var colorScheme
    let imageName: String
    let title: String
    let tintColor: Color
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(gradient: Gradient(colors: [tintColor.opacity(0.80),
                                                       tintColor.opacity(0.60)]),
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .clipShape(RoundedRectangle(cornerRadius: 15.0))
                .frame(width: 180, height: 90)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5) // Subtle shadow
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.leading, 13)
                    .padding(.top, 5)
                
                Spacer() // Pushes content to the top
                
                HStack {
                    Spacer() // Pushes content to the right
                    Image(systemName: imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 35, height: 35)
                        .foregroundColor(.white)
                        .padding(.bottom, 10)
                        .padding(.trailing, 13)
                }
            }
        }
    }
}



#Preview {
    DisplayCards(imageName: "pencil", title: "QuickTest", tintColor: .red)
}
