//
//  UserStatsView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 12/6/23.
//

// UserStatsView.swift
import SwiftUI

struct UserStatsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var quizViewModel: QuizViewModel

    var body: some View {
        VStack {
            if let userProgress = quizViewModel.userProgress, !userProgress.progress.isEmpty {
                ForEach(userProgress.progress.keys.sorted(), id: \.self) { subjectKey in
                    if let subjectProgress = userProgress.progress[subjectKey] {
                        Text("\(subjectKey) - Attempted: \(subjectProgress.questionsAttempted), Correct: \(subjectProgress.questionsCorrect)")
                    }
                }
            } else {
                Text("No user progress available")
                // Button to add dummy data
                if let userID = authViewModel.currentUser?.id {
                    Button("Add Dummy Data") {
                        quizViewModel.addDummyDataForUser(userId: userID)
                    }
                }
            }
        }
        .onAppear {
            if let userID = authViewModel.currentUser?.id {
                quizViewModel.fetchUserProgress(forUserID: userID)
            }
        }
    }
}


#Preview {
    UserStatsView()
        .environmentObject(AuthViewModel())
        .environmentObject(QuizViewModel(authViewModel: AuthViewModel()))
}
