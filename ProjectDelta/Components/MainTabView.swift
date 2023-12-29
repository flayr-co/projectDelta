//
//  MainTabView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/31/23.
//

// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @EnvironmentObject var quizViewModel: QuizViewModel
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            
            CardView()
                .tabItem { Label("Practice", systemImage: "pencil.line") }
            
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
        }
            .onAppear() {
                Task {
                    do {
                        let subjects = try await quizViewModel.fetchSubjectsFromFirestore()
                        print("Fetched subjects: \(subjects)")
                    } catch {
                        print("An error occurred while fetching subjects: \(error.localizedDescription)")
                    }
                }
            }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(QuizViewModel(authViewModel: AuthViewModel()))
}
