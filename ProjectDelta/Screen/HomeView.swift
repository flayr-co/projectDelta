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
                HStack {
                    Text(dashboardText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("\(viewModel.currentUser?.points ?? 0) pts")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            Text("Level \((viewModel.currentUser?.points ?? 0) / 100 + 1)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(colorScheme == .dark ? .cyan : .blue)
                        }
                        
                        ProgressBar(points: viewModel.currentUser?.points ?? 0)
                            .frame(width: 120, height: 8)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    (colorScheme == .dark ? Color.customDarkGray : Color.white)
                        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
                )
                .zIndex(1)
                
                // MARK: - MAIN CONTENT
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        Text("Your learning progress...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                        
                        // Integrated modern metrics presentation ledger
                        UserProgressPieChart()
                            .padding(.horizontal, 24)

                        LazyVGrid(columns: columns, spacing: 16) {
                            NavigationLink(destination: SubjectGridView(navigationSource: .homeView).navigationBarBackButtonHidden(true)) {
                                DisplayCards(imageName: "studentdesk", title: "Learn", tintColor: .cyan)
                            }
                            .buttonStyle(.plain) // CRITICAL: Eradicates the gray NavigationLink boxes
                            
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
        guard let role = viewModel.currentUser?.role else {
            return "Dashboard"
        }
        
        switch role {
        case .student:
            return "Student Dashboard"
        case .teacher:
            return "Teacher Dashboard"
        case .parent:
            return "Parent Dashboard"
        }
    }
}

#Preview {
    HomeView()
        .environment(AuthViewModel())
        .environment(QuizViewModel(authViewModel: AuthViewModel()))
        .environment(LessonViewModel())
}
