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
    @EnvironmentObject var viewModel: AuthViewModel
    @EnvironmentObject var quizViewModel: QuizViewModel
    @EnvironmentObject var lessonVM: LessonViewModel
    
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
                    Text("Your learning progress")
                        .font(.headline)
                    
                    BarChartView()
                        .id(refreshKey)
                    
                    Text("Explore Delta")
                        .font(.headline)
                    
                    LazyVGrid(columns: columns, spacing: 15) {
                        NavigationLink(destination: SubjectGridView(navigationSource: .testView)
                                        .environmentObject(quizViewModel)
                                        .environmentObject(lessonVM)
                                        .navigationBarBackButtonHidden(true)) {
                                            DisplayCards(imageName: "pencil", title: "Test", tintColor: .red)
                                        }
                        
                        NavigationLink(destination: SubjectGridView(navigationSource: .homeView)
                                        .environmentObject(quizViewModel)
                                        .environmentObject(lessonVM)
                                        .navigationBarBackButtonHidden(true)) {
                            DisplayCards(imageName: "studentdesk", title: "Learn", tintColor: .cyan)
                        }

                        NavigationLink(destination: AdminView().navigationBarBackButtonHidden(true)) {
                            DisplayCards(imageName: "eyeglasses", title: "Practice", tintColor: .purple)
                        }

                        NavigationLink(destination: LeaderboardView().navigationBarBackButtonHidden(true)) {
                            DisplayCards(imageName: "trophy", title: "Leaderboard", tintColor: .yellow)
                        }
                    }
                }
                .onChange(of: viewModel.currentUser) {
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

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
        .environmentObject(QuizViewModel(authViewModel: AuthViewModel()))
        .environmentObject(LessonViewModel())
        .preferredColorScheme(.dark)
}
