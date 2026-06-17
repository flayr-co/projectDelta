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
        VStack(spacing: 0) {
            // Native Desktop Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dashboardText)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    Text("Overview & Analytics")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Structured Desktop Stats Pill
                HStack(spacing: 16) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Level \((viewModel.currentUser?.points ?? 0) / 100 + 1)")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.accentColor)
                        Text("\(viewModel.currentUser?.points ?? 0) pts")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                    ProgressBar(points: viewModel.currentUser?.points ?? 0)
                        .frame(width: 120, height: 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.platformSecondarySystemBackground)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.15), lineWidth: 1))
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
            .background(Color.platformSystemBackground)
            
            Divider()
            
            // Asymmetric Split Layout Content
            ScrollView(showsIndicators: false) {
                HStack(alignment: .top, spacing: 40) {
                    
                    // Left Column: Main Analytics
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Performance Metrics")
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        MetricsCarouselView(progress: testViewModel.userProgress)
                            .frame(height: 380)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Right Column: Pinned Quick Actions Sidebar
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Quick Actions")
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 16) {
                            NavigationLink(destination: SubjectGridView(navigationSource: .learn).navigationBarBackButtonHidden(true)) {
                                DisplayCards(imageName: "studentdesk", title: "Learn", tintColor: .cyan)
                            }
                            .buttonStyle(.plain)
                            
                            NavigationLink(destination: PracticeView().navigationBarBackButtonHidden(true)) {
                                DisplayCards(imageName: "pencil", title: "Practice", tintColor: .orange)
                            }
                            .buttonStyle(.plain)
                            
                            NavigationLink(destination: LeaderboardView().navigationBarBackButtonHidden(true)) {
                                DisplayCards(imageName: "trophy", title: "Leaderboard", tintColor: .yellow)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 280) // Fixed sidebar width
                }
                .padding(40)
                .frame(maxWidth: 1400) // Constrains width on ultra-wide monitors
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(Color.platformSystemGroupedBackground)
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
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 20)
            .background(
                (colorScheme == .dark ? Color.customDarkGray : Color.white)
                    .ignoresSafeArea(edges: .top)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
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
                        .frame(height: 240) // Increased vertical footprint for better presence
                        .padding(.horizontal, 24)

                    LazyVGrid(columns: columns, spacing: 16) {
                        NavigationLink(destination: SubjectGridView(navigationSource: .learn).navigationBarBackButtonHidden(true)) {
                            DisplayCards(imageName: "studentdesk", title: "Learn", tintColor: .cyan)
                        }
                        .buttonStyle(.plain)
                        
                        NavigationLink(destination: PracticeView().navigationBarBackButtonHidden(true)) {
                            DisplayCards(imageName: "pencil", title: "Practice", tintColor: .orange)
                        }
                        .buttonStyle(.plain)
                        
                        NavigationLink(destination: LeaderboardView().navigationBarBackButtonHidden(true)) {
                            DisplayCards(imageName: "trophy", title: "Leaderboard", tintColor: .yellow)
                        }
                        .buttonStyle(.plain)
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
