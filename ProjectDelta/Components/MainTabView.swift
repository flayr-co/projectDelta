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
                quizViewModel.fetchSubjectsFromFirestore()
            }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(QuizViewModel(authViewModel: AuthViewModel()))
}
