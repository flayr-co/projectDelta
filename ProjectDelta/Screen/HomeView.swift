//
//  HomeView.swift
//  ProjectDelta
//

import SwiftUI

struct HomeView: View {
    // MARK: - PROPERTIES
    @Environment(AuthViewModel.self) var viewModel
    @Environment(TestSessionViewModel.self) var testViewModel
    @Environment(LessonViewModel.self) var lessonVM
    
    @State private var refreshKey = UUID()
    @Environment(\.colorScheme) var colorScheme
    
    // macOS Specific State Properties
    @State private var totalVolume: Int = 18
    @State private var accuracy: Double = 0.77
    @State private var algebraCorrect: Int = 14
    @State private var algebraTotal: Int = 18
    
    #if os(iOS)
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    #endif
    
    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                macOSDashboard
                #else
                iOSDashboard
                #endif
            }
            .id(refreshKey)
            .onChange(of: viewModel.currentUser) { oldValue, newValue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    refreshKey = UUID()
                }
            }
            .task {
                await loadProgress()
            }
        }
    }
    
    private func loadProgress() async {
        guard let userId = viewModel.userSession?.uid else { return }
        do {
            if let fetchedProgress = try await viewModel.fetchUserProgress(forUserID: userId) {
                testViewModel.userProgress = fetchedProgress
            }
        } catch {
            print("Error running background progress load sync on HomeView: \(error.localizedDescription)")
        }
    }
    
    private var dashboardText: String {
        guard let role = viewModel.currentUser?.role else { return "Dashboard" }
        switch role {
        case .student: return "Student Dashboard"
        case .teacher: return "Teacher Dashboard"
        case .parent: return "Parent Dashboard"
        }
    }

    // MARK: - DESKTOP DASHBOARD (macOS)
    #if os(macOS)
    private var macOSDashboard: some View {
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
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dashboardText)
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
                    Text("Level \((viewModel.currentUser?.points ?? 0) / 100 + 1)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.cyan)
                    Text("\(viewModel.currentUser?.points ?? 0) pts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                ProgressView(value: Double((viewModel.currentUser?.points ?? 0) % 100) / 100.0)
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
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: Color.cyan.opacity(0.15), radius: 12, y: 4)
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
                    .shadow(color: Color.cyan.opacity(0.4), radius: 8, y: 2)
                
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
                .stroke(Color.cyan.opacity(0.2), lineWidth: 1.5)
        )
        .shadow(color: Color.cyan.opacity(0.1), radius: 15, y: 5)
    }
    
    private var statsGrid: some View {
        // Adaptive grid takes full advantage of horizontal space on Mac
        let columns = [
            GridItem(.adaptive(minimum: 180, maximum: .infinity), spacing: 24)
        ]
        
        return LazyVGrid(columns: columns, spacing: 24) {
            StatCardView(icon: "bolt.fill", iconColor: .orange, title: "Total Volume", value: "\(totalVolume)")
            StatCardView(icon: "target", iconColor: .green, title: "Overall Accuracy", value: "\(Int(accuracy * 100))%")
            StatCardView(icon: "function", iconColor: .purple, title: "Advanced Math", value: "0 / 0")
            StatCardView(icon: "x.squareroot", iconColor: .cyan, title: "Algebra", value: "\(algebraCorrect) / \(algebraTotal)")
            StatCardView(icon: "angle", iconColor: .indigo, title: "Geometry & Trig", value: "0 / 0")
            StatCardView(icon: "chart.bar.fill", iconColor: .teal, title: "Problem Solving", value: "0 / 0")
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
    #endif

    // MARK: - MOBILE DASHBOARD (iOS)
    #if os(iOS)
    private var iOSDashboard: some View {
        VStack(spacing: 0) {
            // MARK: - HEADER
            HStack(alignment: .bottom) {
                Text(dashboardText)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("\(viewModel.currentUser?.points ?? 0) pts")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                        
                        Text("Level \((viewModel.currentUser?.points ?? 0) / 100 + 1)")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(colorScheme == .dark ? .cyan : .blue)
                    }
                    
                    ProgressBar(points: viewModel.currentUser?.points ?? 0)
                        .frame(width: 140, height: 10)
                        .shadow(color: (colorScheme == .dark ? Color.cyan : Color.blue).opacity(0.3), radius: 6, y: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 20)
            .background(
                (colorScheme == .dark ? Color.customDarkGray : Color.white)
                    .ignoresSafeArea(edges: .top)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
            .zIndex(1)
            
            // MARK: - MAIN CONTENT
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your Learning Analytics")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    
                    // Expanded Metrics Carousel Slider
                    MetricsCarouselView(progress: testViewModel.userProgress)
                        .frame(height: 240)
                        .padding(.horizontal, 24)

                    LazyVGrid(columns: columns, spacing: 16) {
                        NavigationLink(destination: SubjectGridView(navigationSource: .learn).navigationBarBackButtonHidden(true)) {
                            DisplayCards(imageName: "studentdesk", title: "Learn", tintColor: .cyan)
                        }
                        .buttonStyle(.plain)
                        .shadow(color: Color.cyan.opacity(0.15), radius: 10, y: 4)
                        
                        NavigationLink(destination: SubjectGridView(navigationSource: .practice).navigationBarBackButtonHidden(true)) {
                            DisplayCards(imageName: "pencil", title: "Practice", tintColor: .orange)
                        }
                        .buttonStyle(.plain)
                        .shadow(color: Color.orange.opacity(0.15), radius: 10, y: 4)
                        
                        NavigationLink(destination: LeaderboardView().navigationBarBackButtonHidden(true)) {
                            DisplayCards(imageName: "trophy", title: "Leaderboard", tintColor: .yellow)
                        }
                        .buttonStyle(.plain)
                        .shadow(color: Color.yellow.opacity(0.15), radius: 10, y: 4)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 120)
                }
            }
            .background(colorScheme == .dark ? Color.customDarkGray : Color.gray.opacity(0.05))
        }
    }
    #endif
}

// MARK: - Helper Views (macOS)
#if os(macOS)
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
                .shadow(color: color.opacity(0.5), radius: 4, y: 1)
            
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
                    .shadow(color: iconColor.opacity(0.3), radius: 6, y: 2)
                
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
                .stroke(iconColor.opacity(0.25), lineWidth: 1.5)
        )
        .shadow(color: iconColor.opacity(0.12), radius: 12, y: 4)
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
                    colors: [color.opacity(0.9), color.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: color.opacity(0.25), radius: 15, y: 6)
        }
        .buttonStyle(.plain)
    }
}
#endif
