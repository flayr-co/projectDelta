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
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
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
                            .padding(.top, 10)

                        LazyVGrid(columns: columns, spacing: 20) {
                            NavigationLink(destination: SubjectGridView(navigationSource: .homeView).navigationBarBackButtonHidden(true)) {
                                DisplayCards(imageName: "studentdesk", title: "Learn", tintColor: .cyan)
                            }
                            
                            // FIXED: Removed the irrelevant PracticeView() boilerplate.
                            // This now routes directly to the SubjectGrid so the user can select a subject to take a test on.
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
            .onChange(of: viewModel.currentUser) { oldValue, newValue in
                refreshKey = UUID()
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
