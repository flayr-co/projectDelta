//
//  UserStatsView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 12/6/23.
//

// UserStatsView.swift
import SwiftUI

struct UserStatsView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(QuizViewModel.self) var quizViewModel

    var body: some View {
//        VStack {
//            if let userProgress = quizViewModel.userProgress, !userProgress.progress.isEmpty {
//                ForEach(userProgress.progress.keys.sorted(), id: \.self) { subjectKey in
//                    if let subjectProgress = userProgress.progress[subjectKey] {
//                        Text("\(subjectKey.rawValue) - Attempted: \(subjectProgress.questionsAttempted), Correct: \(subjectProgress.questionsCorrect)")
//                    }
//                }
//            } else {
//                Text("No user progress available")
//                // Button to add dummy data
//                if let userID = authViewModel.currentUser?.id {
//                    Button("Add Dummy Data") {
//                        quizViewModel.addDummyDataForUser(userId: userID)
//                    }
//                }
//            }
//        }
//        .task {
//            if let userID = authViewModel.currentUser?.id {
//                await quizViewModel.fetchUserProgress(forUserID: userID)
//            }
//        }
        
        Text("the user stats view will go here")
    }
}

#Preview {
    UserStatsView()
        .environment(AuthViewModel())
        .environment(QuizViewModel(authViewModel: AuthViewModel()))
}
