//
//  ProjectDeltaApp.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/6/23.
//

import SwiftUI
import FirebaseCore

// Kept for future Apple ecosystem delegates (Push Notifications, Deep Linking, etc.)
// Firebase configuration is removed from here to prevent double-execution.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}

@main
struct ProjectDeltaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Declare states without immediate assignment to prevent early execution
    @State var viewModel: AuthViewModel
    @State var quizViewModel: QuizViewModel
    @State var lessonVM: LessonViewModel
    
    init() {
        // 1. Force Firebase to configure absolutely first
        FirebaseApp.configure()
        
        // 2. Initialize ViewModels safely AFTER Firebase is active
        let auth = AuthViewModel()
        _viewModel = State(initialValue: auth)
        _quizViewModel = State(initialValue: QuizViewModel(authViewModel: auth))
        _lessonVM = State(initialValue: LessonViewModel())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .environment(quizViewModel)
                .environment(lessonVM)
        }
    }
}
