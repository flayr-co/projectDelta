//
//  HomeView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/31/23.
//

import SwiftUI

struct HomeView: View {
    // MARK: - PROPERTIES
    @Environment(AuthViewModel.self) var viewModel
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(LessonViewModel.self) var lessonVM
    
    @State private var selectedSubject: String?
    @State private var isShowingSubjectGrid = false
    @State private var refreshKey = UUID()
    @Environment(\.colorScheme) var colorScheme
    
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    
    var body: some View {
        NavigationStack {
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
                                .monospacedDigit() // Precision styling
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
                    VStack(alignment: .leading, spacing: 28) {
                        Text("Your learning progress")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                        
                        UserProgressPieChart()
                            .padding(.horizontal, 24)

                        LazyVGrid(columns: columns, spacing: 16) {
                            NavigationLink(destination: SubjectGridView(navigationSource: .homeView).navigationBarBackButtonHidden(true)) {
                                DisplayCards(imageName: "studentdesk", title: "Learn", tintColor: .cyan)
                            }
                            .buttonStyle(.plain)
                            
                            NavigationLink(destination: SubjectGridView(navigationSource: .testView).navigationBarBackButtonHidden(true)) {
                                DisplayCards(imageName: "eyeglasses", title: "Practice", tintColor: .purple)
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
            .id(refreshKey)
            .onChange(of: viewModel.currentUser) { oldValue, newValue in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    refreshKey = UUID()
                }
            }
            .task {
                guard let userId = viewModel.userSession?.uid else { return }
                do {
                    if let fetchedProgress = try await viewModel.fetchUserProgress(forUserID: userId) {
                        quizViewModel.userProgress = fetchedProgress
                    }
                } catch {
                    print("Error running background progress load sync on HomeView: \(error.localizedDescription)")
                }
            }
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
}
