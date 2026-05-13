//
//  HomeView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/31/23.
//

// HomeView.swift
import SwiftUI

struct HomeView: View {
    // MARK: - PROPERTIES
    // Upgraded to native Environment framework mappings
    @Environment(AuthViewModel.self) var viewModel
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(LessonViewModel.self) var lessonVM
    
    @State private var selectedSubject: String? // Holds user's selected subject
    @State private var isShowingSubjectGrid = false
    @State private var refreshKey = UUID()
    @Environment(\.colorScheme) var colorScheme
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        // MARK: - HEADER
        
        NavigationStack {
            HStack(spacing: 80) {
                Text(dashboardText)
                    .font(.title3)
                    .fontWeight(.medium)
                
                VStack {
                    HStack {
                        Text("\(viewModel.currentUser?.points ?? 0)")
                            .font(.subheadline)
                        Text("Level \((viewModel.currentUser?.points ?? 0) / 100 + 1)")
                            .font(.subheadline)
                    }
                    
                    ProgressBar(points: viewModel.currentUser?.points ?? 0)
                        .frame(width: 150)
                }
            }
            
            ScrollView {
                VStack {
                    Text("Your learning progress...") // Placeholder to match your original truncated snippet
                        .padding()

                    LazyVGrid(columns: columns, spacing: 20) {
                        NavigationLink(destination: SubjectGridView(navigationSource: .homeView).navigationBarBackButtonHidden(true)) {
                            DisplayCards(imageName: "studentdesk", title: "Learn", tintColor: .cyan)
                        }
                        
                        NavigationLink(destination: PracticeView().navigationBarBackButtonHidden(true)) {
                            DisplayCards(imageName: "eyeglasses", title: "Practice", tintColor: .purple)
                        }
                        
                        NavigationLink(destination: LeaderboardView().navigationBarBackButtonHidden(true)) {
                            DisplayCards(imageName: "trophy", title: "Leaderboard", tintColor: .yellow)
                        }
                    }
                }
                // Upgraded to iOS 17 double-parameter onChange signature
                .onChange(of: viewModel.currentUser) { oldValue, newValue in
                    refreshKey = UUID() // To refresh the view
                }
            }
        } //: NAVIGATIONSTACK
    } //: BODY
    
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

// Modernized preview wrapper
#Preview {
    HomeView()
        .environment(AuthViewModel())
        .environment(QuizViewModel(authViewModel: AuthViewModel()))
        .environment(LessonViewModel())
}
