//
//  ProjectDeltaApp.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/6/23.
//

import SwiftUI
import Firebase


@main
struct ProjectDeltaApp: App {
    @StateObject var viewModel = AuthViewModel()
    @StateObject var quizViewModel = QuizViewModel(authViewModel: AuthViewModel())
    @StateObject var lessonVM = LessonViewModel(subjectName: "Geometry")
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(quizViewModel)
                .environmentObject(lessonVM)
        }
    }
}
