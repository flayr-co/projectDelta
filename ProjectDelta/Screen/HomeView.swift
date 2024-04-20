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
    
    @State private var selectedSubject: String? // Holds user's selected subject
    @State private var isShowingSubjectGrid = false
    @State private var refreshKey = UUID()
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        // MARK: - HEADER
        
        NavigationStack {
            HStack(spacing: 80) {
                Text("Dashboard")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack {
                    HStack {
                        Text("\(viewModel.currentUser?.points ?? 0)")
                            .font(.subheadline)
                        Text("Level \((viewModel.currentUser?.points ?? 0) / 100 + 1)")
                            .font(.subheadline)
                    }
                    
                    // Updated to use ProgressBar
                    ProgressBar(points: viewModel.currentUser?.points ?? 0)
                        .frame(width: 150) // Specify the desired width of the progress bar
                }
            }
            
            // MARK: - MAIN CONTENT
            
            ScrollView{
                VStack {
                    VStack {
                        Text("Your learning progress") // chart will go below this displaying the user's study progress with their points earned in each day for 7 days
                            .font(.headline)
                        
                        // SLIDER SWIPE HERE
                        BarChartView(user: viewModel.currentUser ?? User.MOCK_USERS[0])
                            .id(refreshKey)
//                        UserProgressPieChart()
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 33)
                    
                    // MARK: - BOTTOM CONTENT
                    
                    VStack {
                        Text("Explore Delta")
                            .font(.headline)
                        
                        LazyVGrid(columns: columns, spacing: 15) {
                            NavigationLink {
                                AddQuestionView()
                                    .navigationBarBackButtonHidden(true)
                            } label: {
                                DisplayCards(imageName: "pencil", title: "Quick Test", tintColor: .red)
                            }
                            
                        // We use an empty string as the default value and it will be replaced when a subject is selected
                            Button(action: {
                                isShowingSubjectGrid = true // When "Learn" is tapped, show the SubjectGridView
                            }) {
                                DisplayCards(imageName: "studentdesk", title: "Learn", tintColor: .cyan)
                            }
                            .navigationDestination(isPresented: $isShowingSubjectGrid) {
                                // Navigate to SubjectGridView when isShowingSubjectGrid is true
                                SubjectGridView(navigationSource: .homeView)
                                    .environmentObject(quizViewModel)
                            }
                            
                            NavigationLink {
//                                UserStatsView()
                                AdminView()
                                    .navigationBarBackButtonHidden(true)
                            } label: {
                                DisplayCards(imageName: "eyeglasses", title: "Practice", tintColor: .purple)
                            }
                            
                            NavigationLink {
                                LeaderboardView()
                                    .navigationBarBackButtonHidden(true)
                            } label: {
                                DisplayCards(imageName: "trophy", title: "Leaderboard", tintColor: .yellow)
                            }
                        }
                    } //: VSTACK
                }
                .onChange(of: viewModel.currentUser) { _ in
                    refreshKey = UUID() // Change the key to refresh the view
                }
            }
        } //: NavigationStack
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
        .environmentObject(QuizViewModel(authViewModel: AuthViewModel()))
}
