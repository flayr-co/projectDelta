//
//  MetricsCarouselView.swift
//  ProjectDelta
//

import SwiftUI

struct MetricsCarouselView: View {
    let progress: UserProgress?
    
    var body: some View {
        Group {
            #if os(macOS)
            macOSLayout
            #else
            iOSLayout
            #endif
        }
    }
    
    // MARK: - DESKTOP LAYOUT (macOS)
    #if os(macOS)
    private var macOSLayout: some View {
        HStack(alignment: .top, spacing: 32) {
            
            // Left: Pinned Analytics Panel (Expanded Strict Anchor Width)
            VStack(alignment: .center, spacing: 0) {
                UserProgressPieChart()
                    .padding(16) // Minimized padding to maximize internal space for text
            }
            .frame(width: 460) // Significantly expanded to prevent text crushing
            // Ensure the left panel matches the height of the dynamically expanding right grid
            .frame(minHeight: 380, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.platformSystemBackground)
                    .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            // Right: Strict 2-Column Responsive Grid
            // Removed nested ScrollView so it sizes natively and allows the parent scroll view in HomeView to manage overflow.
            VStack(spacing: 24) {
                let desktopColumns = [
                    GridItem(.flexible(), spacing: 24),
                    GridItem(.flexible(), spacing: 24)
                ]
                
                LazyVGrid(columns: desktopColumns, spacing: 24) {
                    MetricCard(title: "Total Volume", value: "\(progress?.questionsAttempted ?? 0)", icon: "bolt.fill", color: .orange)
                        .frame(minHeight: 140)
                    
                    MetricCard(title: "Accuracy", value: accuracyPercentage, icon: "target", color: .green)
                        .frame(minHeight: 140)
                    
                    if let prog = progress {
                        ForEach(Array(prog.progress.sorted(by: { $0.key.rawValue < $1.key.rawValue })), id: \.key) { key, value in
                            MetricCard(
                                title: key.rawValue,
                                value: "\(value.questionsCorrect) / \(value.questionsAttempted)",
                                icon: "book.fill",
                                color: .cyan
                            )
                            .frame(minHeight: 140)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
    }
    #endif
    
    // MARK: - MOBILE LAYOUT (iOS)
    #if os(iOS)
    private var iOSLayout: some View {
        TabView {
            // First Slide
            UserProgressPieChart()
                .padding(16) // Reduced padding here as well
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
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
    }
    #endif
    
    // MARK: - CALCULATIONS
    private var accuracyPercentage: String {
        guard let prog = progress, prog.questionsAttempted > 0 else { return "0%" }
        let totalCorrect = prog.progress.values.reduce(0) { $0 + $1.questionsCorrect }
        let percent = (Double(totalCorrect) / Double(prog.questionsAttempted)) * 100
        return "\(Int(percent))%"
    }
}

// MARK: - METRIC CARD COMPONENT
struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(.secondary)
                    .minimumScaleFactor(0.75) // Ensure strings like "Advanced Math" scale appropriately instead of cutting off
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 0)
            
            Text(value)
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.platformSystemBackground)
                .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
