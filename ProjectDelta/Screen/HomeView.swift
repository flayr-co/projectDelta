//
//  HomeView.swift
//  ProjectDelta
//

import SwiftUI

struct HomeView: View {
    // MARK: - State Properties
    @State private var totalVolume: Int = 18
    @State private var accuracy: Double = 0.77
    @State private var algebraCorrect: Int = 14
    @State private var algebraTotal: Int = 18
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    headerSection
                    contentSection
                }
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.95, green: 0.95, blue: 0.97))
        }
        .task {
            await fetchDashboardMetrics()
        }
    }
        
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Teacher Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                
                Text("Overview & Analytics")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Level Indicator
            HStack(spacing: 16) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Level 1")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.cyan)
                    Text("80 pts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                ProgressView(value: 0.8)
                    .progressViewStyle(.linear)
                    .tint(Color.cyan)
                    .frame(width: 150)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.15) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)
            )
        }
    }
        
    private var contentSection: some View {
        HStack(alignment: .top, spacing: 32) {
            // Left Column: Performance Metrics (Expands dynamically)
            VStack(alignment: .leading, spacing: 24) {
                Text("Performance Metrics")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                
                HStack(alignment: .top, spacing: 24) {
                    donutChartCard
                        .frame(maxWidth: 400)
                    
                    statsGrid
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right Column: Quick Actions (Flexible but bounded)
            VStack(alignment: .leading, spacing: 24) {
                Text("Quick Actions")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                
                quickActionsList
            }
            .frame(minWidth: 250, idealWidth: 300, maxWidth: 350)
        }
    }
        
    private var donutChartCard: some View {
        VStack(spacing: 32) {
            // Donut Chart
            ZStack {
                Circle()
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 32)
                
                Circle()
                    .trim(from: 0, to: CGFloat(Double(algebraCorrect) / Double(algebraTotal)))
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 32, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("\(algebraCorrect)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? .white : .primary)
                    Text("CORRECT")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 220, height: 220)
            .padding(.top, 16)
            
            // Legend
            VStack(alignment: .leading, spacing: 20) {
                LegendItemView(color: .cyan, title: "Algebra", value: "\(algebraCorrect)/\(algebraTotal) correct")
                LegendItemView(color: .purple, title: "Advanced Math", value: "0/0 correct")
                LegendItemView(color: .orange, title: "Problem Solving & Data Analysis", value: "0/0 correct")
                LegendItemView(color: .green, title: "Geometry & Trigonometry", value: "0/0 correct")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(32)
        .background(colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)
        )
    }
    
    private var statsGrid: some View {
        // Adaptive grid takes full advantage of horizontal space on Mac
        let columns = [
            GridItem(.adaptive(minimum: 180, maximum: .infinity), spacing: 24)
        ]
        
        return LazyVGrid(columns: columns, spacing: 24) {
            StatCardView(icon: "bolt.fill", iconColor: .orange, title: "Total Volume", value: "\(totalVolume)")
            StatCardView(icon: "target", iconColor: .green, title: "Overall Accuracy", value: "\(Int(accuracy * 100))%")
            StatCardView(icon: "function", iconColor: .cyan, title: "Advanced Math", value: "0 / 0")
            StatCardView(icon: "x.squareroot", iconColor: .cyan, title: "Algebra", value: "\(algebraCorrect) / \(algebraTotal)")
            StatCardView(icon: "angle", iconColor: .cyan, title: "Geometry & Trig", value: "0 / 0")
            StatCardView(icon: "chart.bar.fill", iconColor: .cyan, title: "Problem Solving", value: "0 / 0")
        }
        .frame(maxWidth: .infinity)
    }
    
    private var quickActionsList: some View {
        VStack(spacing: 24) {
            ActionCardButton(
                title: "Learn",
                icon: "desktopcomputer",
                color: .cyan,
                destination: SubjectGridView(navigationSource: .learn).navigationBarBackButtonHidden(true)
            )
            ActionCardButton(
                title: "Practice",
                icon: "pencil",
                color: .orange,
                destination: SubjectGridView(navigationSource: .practice).navigationBarBackButtonHidden(true)
            )
            ActionCardButton(
                title: "Leaderboard",
                icon: "trophy",
                color: .yellow,
                destination: LeaderboardView().navigationBarBackButtonHidden(true)
            )
            
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Methods
    
    private func fetchDashboardMetrics() async {
        // Implementation for async data retrieval goes here.
        // Replace with network or Firestore logic.
        try? await Task.sleep(for: .seconds(1))
    }
}

// MARK: - Helper Views

struct LegendItemView: View {
    let color: Color
    let title: String
    let value: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StatCardView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.15))
                    .clipShape(Circle())
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

struct ActionCardButton<Destination: View>: View {
    let title: String
    let icon: String
    let color: Color
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Image(systemName: icon)
                    .font(.title)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                LinearGradient(
                    colors: [color.opacity(0.85), color.opacity(0.65)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .frame(minWidth: 1000, minHeight: 800)
}
