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
                Text("Welcome back,")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text(dashboardText)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                
                Text("Overview & Analytics")
                    .font(.system(.headline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Level Indicator
            HStack(spacing: 20) {
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Level \((viewModel.currentUser?.points ?? 0) / 100 + 1)")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(Color.cyan)
                        
                        Circle()
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: 4, height: 4)
                        
                        Text("\(viewModel.currentUser?.points ?? 0) pts")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    
                    GeometryReader { geo in
                        let progressVal = Double((viewModel.currentUser?.points ?? 0) % 100) / 100.0
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.2))
                            
                            Capsule()
                                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(progressVal))
                                .shadow(color: .cyan.opacity(0.6), radius: 6, y: 0)
                        }
                    }
                    .frame(height: 8)
                }
                .frame(width: 200)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.15) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1.5)
            )
            .shadow(color: Color.cyan.opacity(0.15), radius: 10, y: 4)
        }
    }
    
    private var contentSection: some View {
        HStack(alignment: .top, spacing: 24) {
            // Left & Middle: Performance Metrics
            VStack(alignment: .leading, spacing: 20) {
                Text("Performance Metrics")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                
                HStack(alignment: .top, spacing: 20) {
                    donutChartCard
                        .frame(width: 320) // Tightened width for better symmetry
                    
                    statsGrid
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right: Quick Actions
            VStack(alignment: .leading, spacing: 20) {
                Text("Quick Actions")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                
                quickActionsList
            }
            .frame(width: 280) // Tightened right column
        }
    }
    
    private var donutChartCard: some View {
        let progress = testViewModel.userProgress
        let dynamicSubjects = progress != nil ? Array(progress!.progress.keys).sorted() : []
        let chartColors: [Color] = [.cyan, .purple, .orange, .green, .pink, .indigo, .mint, .yellow, .red, .teal]
        
        let totalCorrect = dynamicSubjects.reduce(0) { $0 + (progress?.progress[$1]?.questionsCorrect ?? 0) }
        let totalAttempted = dynamicSubjects.reduce(0) { $0 + (progress?.progress[$1]?.questionsAttempted ?? 0) }
        let percentage = totalAttempted > 0 ? CGFloat(Double(totalCorrect) / Double(totalAttempted)) : 0.0
        
        return VStack(spacing: 24) { // Reduced from 40
            // Donut Chart
            ZStack {
                Circle()
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 24) // Reduced from 36
                
                Circle()
                    .trim(from: 0, to: percentage)
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.cyan.opacity(0.5), radius: 10, y: 0)
                
                VStack(spacing: 2) {
                    Text("\(totalCorrect)")
                        .font(.system(size: 48, weight: .bold, design: .rounded)) // Scaled down slightly
                        .foregroundStyle(colorScheme == .dark ? .white : .primary)
                    Text("CORRECT")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 180, height: 180) // Reduced from 240
            .padding(.top, 16)
            
            // Legend
            VStack(alignment: .leading, spacing: 16) { // Tighter legend spacing
                if dynamicSubjects.isEmpty {
                    LegendItemView(color: .gray, title: "No Data", value: "0/0 correct")
                } else {
                    ForEach(Array(dynamicSubjects.enumerated()), id: \.element) { index, subject in
                        let stats = progress?.progress[subject] ?? SubjectProgress(questionsAttempted: 0, questionsCorrect: 0)
                        LegendItemView(color: chartColors[index % chartColors.count], title: subject, value: "\(stats.questionsCorrect)/\(stats.questionsAttempted) correct")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
        .padding(24) // Reduced overall padding
        .background(colorScheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.13) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: Color.cyan.opacity(0.12), radius: 15, y: 6)
    }
    
    private var statsGrid: some View {
        let progress = testViewModel.userProgress
        let dynamicSubjects = progress != nil ? Array(progress!.progress.keys).sorted() : []
        let chartColors: [Color] = [.cyan, .purple, .orange, .green, .pink, .indigo, .mint, .yellow, .red, .teal]
        
        let totalAttempted = progress?.questionsAttempted ?? 0
        let totalCorrect = dynamicSubjects.reduce(0) { $0 + (progress?.progress[$1]?.questionsCorrect ?? 0) }
        let accuracy = totalAttempted > 0 ? Int((Double(totalCorrect) / Double(totalAttempted)) * 100) : 0
        
        let columns = [
            GridItem(.flexible(), spacing: 16), // Tightened grid gaps
            GridItem(.flexible(), spacing: 16)
        ]
        
        return LazyVGrid(columns: columns, spacing: 16) {
            StatCardView(icon: "bolt.fill", iconColor: .orange, title: "Total Volume", value: "\(totalAttempted)")
            StatCardView(icon: "target", iconColor: .green, title: "Overall Accuracy", value: "\(accuracy)%")
            
            ForEach(Array(dynamicSubjects.enumerated()), id: \.element) { index, subject in
                let stats = progress?.progress[subject] ?? SubjectProgress(questionsAttempted: 0, questionsCorrect: 0)
                StatCardView(
                    icon: "book.fill",
                    iconColor: chartColors[index % chartColors.count],
                    title: subject,
                    value: "\(stats.questionsCorrect) / \(stats.questionsAttempted)"
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var quickActionsList: some View {
        VStack(spacing: 16) { // Matches grid spacing
            ActionCardButton(
                title: "Learn",
                icon: "studentdesk",
                colors: [.cyan, .blue],
                destination: SubjectGridView(navigationSource: .learn).navigationBarBackButtonHidden(true)
            )
            ActionCardButton(
                title: "Practice",
                icon: "pencil",
                colors: [.orange, .red],
                destination: SubjectGridView(navigationSource: .practice).navigationBarBackButtonHidden(true)
            )
            ActionCardButton(
                title: "Leaderboard",
                icon: "trophy.fill",
                colors: [.yellow, .orange],
                destination: LeaderboardView().navigationBarBackButtonHidden(true)
            )
            ActionCardButton(
                title: "Spectroscopy",
                icon: "waveform.path",
                colors: [.purple, .indigo],
                destination: ElectromagneticWaveAnalyzerView()
            )
            Spacer(minLength: 0)
        }
    }
    #endif

    // MARK: - MOBILE DASHBOARD (iOS)
    #if os(iOS)
    private var iOSDashboard: some View {
        VStack(spacing: 0) {
            // MARK: - COMPACT HEADER
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome back,")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Text(dashboardText)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Sleek Level & Points Badge
                VStack(alignment: .trailing, spacing: 5) {
                    HStack(spacing: 5) {
                        Text("Lvl \((viewModel.currentUser?.points ?? 0) / 100 + 1)")
                            .font(.system(.footnote, design: .rounded, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .cyan : .blue)
                        
                        Circle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 3, height: 3)
                        
                        Text("\(viewModel.currentUser?.points ?? 0) pts")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    
                    // Compact Inline Progress Bar
                    GeometryReader { geo in
                        let progressVal = Double((viewModel.currentUser?.points ?? 0) % 100) / 100.0
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                            
                            Capsule()
                                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(progressVal))
                                .shadow(color: .cyan.opacity(0.4), radius: 3, y: 0)
                        }
                    }
                    .frame(width: 96, height: 5)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
            .zIndex(1)
            
            // MARK: - MAIN CONTENT
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 40) {
                    
                    // Analytics Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Analytics")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                        
                        MetricsCarouselView(progress: testViewModel.userProgress)
                            .frame(height: 210)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 40)

                    // Quick Actions Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Actions")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                        
                        LazyVGrid(columns: columns, spacing: 16) {
                            iOSActionCard(
                                title: "Learn",
                                icon: "studentdesk",
                                colors: [.cyan, .blue],
                                destination: SubjectGridView(navigationSource: .learn).navigationBarBackButtonHidden(true)
                            )
                            
                            iOSActionCard(
                                title: "Practice",
                                icon: "pencil",
                                colors: [.orange, .red],
                                destination: SubjectGridView(navigationSource: .practice).navigationBarBackButtonHidden(true)
                            )
                            
                            iOSActionCard(
                                title: "Leaderboard",
                                icon: "trophy.fill",
                                colors: [.yellow, .orange],
                                destination: LeaderboardView().navigationBarBackButtonHidden(true)
                            )
                            
                            iOSActionCard(
                                title: "Spectroscopy",
                                icon: "waveform.path",
                                colors: [.purple, .indigo],
                                destination: ElectromagneticWaveAnalyzerView()
                            )
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Controlled clearance buffer for custom floating tab bar
                    Spacer(minLength: 120)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
    }
    #endif
}

// MARK: - iOS Action Card Component
#if os(iOS)
struct iOSActionCard<Destination: View>: View {
    let title: String
    let icon: String
    let colors: [Color]
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.22))
                        .clipShape(Circle())
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                
                Spacer(minLength: 6)
                
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 96)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: colors.first!.opacity(0.28), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
#endif

// MARK: - Helper Views (macOS)
#if os(macOS)
struct LegendItemView: View {
    let color: Color
    let title: String
    let value: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) { // Slightly tighter gap
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 4)
                .shadow(color: color.opacity(0.6), radius: 4, y: 0)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                Text(value)
                    .font(.system(.caption, design: .rounded, weight: .medium))
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
        VStack(alignment: .leading, spacing: 12) { // Compacted from 24
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32) // Shrunk icon badge
                .background(iconColor.opacity(0.15))
                .clipShape(Circle())
            
            Spacer(minLength: 0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .bold)) // Dropped to caption
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(value)
                    .font(.system(size: 24, weight: .heavy, design: .rounded)) // Dropped value font size
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
            }
        }
        .padding(16) // Reduced padding from 24
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(colorScheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.13) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(iconColor.opacity(0.3), lineWidth: 1.2)
        )
        .shadow(color: iconColor.opacity(0.1), radius: 10, y: 4)
    }
}

struct ActionCardButton<Destination: View>: View {
    let title: String
    let icon: String
    let colors: [Color]
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .bold)) // Reduced font scale
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .opacity(0.9)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24) // Reduced vertical bulk significantly
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: colors.first!.opacity(0.4), radius: 10, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
#endif
