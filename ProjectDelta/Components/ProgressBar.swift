//
//  ProgressBar.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/31/23.
//

import SwiftUI

struct ProgressBar: View {
    let points: Int
    
    // Calculate progress as a fraction (assuming level-up every 100 points)
    private var progress: CGFloat {
        let p = CGFloat(points % 100) / 100.0
        return max(0, min(1, p))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 10)
                
                // Active Progress
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.8), .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
            }
        }
    }
}

#Preview {
    ProgressBar(points: 45)
        .padding()
}
