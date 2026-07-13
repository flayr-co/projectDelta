//
//  ProjectDeltaApp.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/6/23.
//

import SwiftUI
import FirebaseCore

#if os(iOS)
import UIKit

// Kept for future Apple ecosystem delegates (Push Notifications, Deep Linking, etc.)
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}
#elseif os(macOS)
import AppKit

// Kept for future Apple ecosystem delegates on macOS
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // macOS specific launch configurations can go here
    }
}
#endif

@main
struct ProjectDeltaApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #endif
    
    // Declare states without immediate assignment to prevent early execution
    @State var viewModel: AuthViewModel
    @State var testViewModel: TestSessionViewModel
    @State var lessonVM: LessonViewModel
    @State var quizViewModel: QuizViewModel
    
    init() {
        // 1. Force Firebase to configure absolutely first
        FirebaseApp.configure()
        
        // 2. Initialize ViewModels safely AFTER Firebase is active
        let auth = AuthViewModel()
        _viewModel = State(initialValue: auth)
        _testViewModel = State(initialValue: TestSessionViewModel(authViewModel: auth))
        _lessonVM = State(initialValue: LessonViewModel())
        _quizViewModel = State(initialValue: QuizViewModel(authViewModel: auth))
    }
    
    #if os(macOS)
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .environment(testViewModel)
                .environment(lessonVM)
                .environment(quizViewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
    }
    #else
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .environment(testViewModel)
                .environment(lessonVM)
                .environment(quizViewModel)
        }
    }
    #endif
}
