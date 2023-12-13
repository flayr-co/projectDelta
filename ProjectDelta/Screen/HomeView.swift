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
                        Text("\(viewModel.currentUser?.points ?? 0)") // perhaps points (displayed till next level here) will increase by a certain percentage each level (thus making it harder to advance the next level from 100 than 10 for example)
                        
                        Text("Level 2")
                    } // filler here, where users points until next level will be displayed
                    
                    RoundedRectangle(cornerSize: CGSize(width: 20, height: 10))
                        .frame(width: 150, height: 15)  // this will display the users progress on points visually until achieving the next level
                        .foregroundColor(.blue)
                    
                    Text("Your points")
                }
            }
            
            // MARK: - MAIN CONTENT
            
            ScrollView{
                VStack {
                    VStack {
                        Text("Your learning progress") // chart will go below this displaying the user's study progress with their points earned in each day for 7 days
                            .font(.headline)
                        
                        // SLIDER SWIPE HERE
                        BarChartView()
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
                            
                            NavigationLink {
                                AddTestView()
                                    .navigationBarBackButtonHidden(true)
                            } label: {
                                DisplayCards(imageName: "studentdesk", title: "Learn", tintColor: .cyan)
                            }
                            
                            NavigationLink {
                                UserStatsView()
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
                    }
                }
            }
        } //: NavigationStack
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
