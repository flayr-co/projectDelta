//
//  ContentView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/6/23.
//

// ContentView.swift
import SwiftUI
import Firebase
import FirebaseFirestore

struct ContentView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @EnvironmentObject var lessonVM: LessonViewModel
    
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthViewModel())
            .environmentObject(LessonViewModel())
    }
}
