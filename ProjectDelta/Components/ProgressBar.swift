//
//  ProgressBar.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 4/4/24.
//

// Custom ProgressBar View
import SwiftUI

struct ProgressBar: View {
    var points: Int
    
    private var progress: CGFloat {
        CGFloat(points % 100) / 100.0
    }
    private var nextMilestone: Int {
        ((points / 100) + 1) * 100
    }
    
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background of the progress bar
                RoundedRectangle(cornerRadius: 20.0)
                    .frame(width: geometry.size.width, height: 20)
                    .foregroundColor(.gray.opacity(0.3))

                // Filled portion of the progress bar
                RoundedRectangle(cornerRadius: 20.0)
                    .frame(width: geometry.size.width * progress, height: 20)
                    .foregroundColor(.blue)
                    .animation(.linear, value: progress)

                // Default text color, will be visible on the unfilled portion of the bar
                Text("\(points)/\(nextMilestone) points")
                    .frame(width: geometry.size.width, height: 20, alignment: .center)
                    .clipShape(Rectangle().offset(x: geometry.size.width * progress, y: 0))
                
                // White text color, visible only on the filled portion of the bar
                Text("\(points)/\(nextMilestone) points")
                    .foregroundColor(.white)
                    .frame(width: geometry.size.width, height: 20, alignment: .center)
                    .clipShape(Rectangle().offset(x: -geometry.size.width * (1 - progress), y: 0))
            }
        }
        .frame(height: 20) // Specify the fixed height for the progress bar
    }
}

