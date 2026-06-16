//
//  ContentView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/6/23.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct ContentView: View {
    // Upgraded to native Environment for the Observation framework
    @Environment(AuthViewModel.self) var viewModel
    @Environment(LessonViewModel.self) var lessonVM
    
    var body: some View {
        Group {
            if viewModel.userSession != nil {
                MainTabView()
            } else {
                SignInView()
            }
        }
    }
}

// Upgraded to iOS 17 #Preview macro
#Preview {
    let dummyAuth = AuthViewModel()
    return ContentView()
        .environment(dummyAuth)
        .environment(LessonViewModel())
        .environment(PracticeTestViewModel(authViewModel: dummyAuth))
}
