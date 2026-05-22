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
                    
                    VStack(alignment: .trailing, spacing: 4) {
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
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
                
                // MARK: - MAIN CONTENT
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Your learning progress...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 16)
                        
                        // Integrated modern metrics presentation ledger
                        UserProgressPieChart()
                            .padding(.horizontal)

                        LazyVGrid(columns: columns, spacing: 16) {
                            NavigationLink(destination: SubjectGridView(navigationSource: .homeView).navigationBarBackButtonHidden(true)) {
                                DisplayCards(imageName: "studentdesk", title: "Learn", tintColor: .cyan)
                            }
                            
                            NavigationLink(destination: SubjectGridView(navigationSource: .testView).navigationBarBackButtonHidden(true)) {
                                DisplayCards(imageName: "eyeglasses", title: "Practice", tintColor: .purple)
                            }
                            
                            NavigationLink(destination: LeaderboardView().navigationBarBackButtonHidden(true)) {
                                DisplayCards(imageName: "trophy", title: "Leaderboard", tintColor: .yellow)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                    }
                }
                .background(colorScheme == .dark ? Color.customDarkGray : Color.gray.opacity(0.05))
            }
            .id(refreshKey)
            .onChange(of: viewModel.currentUser) { oldValue, newValue in
                refreshKey = UUID()
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
    
    // Computed property to return dashboard text based on user role
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
