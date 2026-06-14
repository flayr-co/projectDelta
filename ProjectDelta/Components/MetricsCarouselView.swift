//
//  MetricsCarouselView.swift
//  ProjectDelta
//

import SwiftUI

struct MetricsCarouselView: View {
    let progress: UserProgress?
    
    var body: some View {
        TabView {
            // First Slide: The original progress view, fully styled to match the new cards
            UserProgressPieChart()
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.platformSystemBackground)
                        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1.5)
                )
                .padding(.horizontal, 4)
                .padding(.vertical, 12)
                .tag(0)

            // Remaining Slides: Data Point Metrics
            MetricCard(title: "Total Volume", value: "\(progress?.questionsAttempted ?? 0)", icon: "bolt.fill", color: .orange)
                .tag(1)
            
            MetricCard(title: "Accuracy", value: accuracyPercentage, icon: "target", color: .green)
                .tag(2)
            
            // Dynamically show per-subject progress
            if let prog = progress {
                ForEach(Array(prog.progress.sorted(by: { $0.key.rawValue < $1.key.rawValue }).enumerated()), id: \.element.key) { index, element in
                    MetricCard(
                        title: element.key.rawValue,
                        value: "\(element.value.questionsCorrect) / \(element.value.questionsAttempted)",
                        icon: "book.fill",
                        color: .cyan
                    )
                    .tag(index + 3)
                }
            }
        }
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
        #endif
    }
    
    private var accuracyPercentage: String {
        guard let prog = progress, prog.questionsAttempted > 0 else { return "0%" }
        let totalCorrect = prog.progress.values.reduce(0) { $0 + $1.questionsCorrect }
        let percent = (Double(totalCorrect) / Double(prog.questionsAttempted)) * 100
        return "\(Int(percent))%"
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.platformSystemBackground)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1.5)
        )
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
    }
}
