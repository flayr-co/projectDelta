//
//  UserProgressDonut.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 12/29/23.
//

import SwiftUI
import Charts

struct UserProgressPieChart: View {
    @Environment(AuthViewModel.self) var viewModel
    @Environment(QuizViewModel.self) var quizViewModel
    
    var body: some View {
        Group {
            if let userProgress = quizViewModel.userProgress {

                Chart {
                    // Focusing only on the Geometry and Trigonometry data
                    if let progressData = userProgress.progress[.geometryTrigonometry] {
                        let correctPercentage = progressData.questionsAttempted > 0 ?
                            Double(progressData.questionsCorrect) / Double(progressData.questionsAttempted) : 0
                        
                        SectorMark(
                            angle: .value(
                                Text(verbatim: SubjectArea.geometryTrigonometry.displayName),
                                correctPercentage
                            )
                        )
                        .foregroundStyle(
                            by: .value(
                                Text(verbatim: SubjectArea.geometryTrigonometry.displayName),
                                SubjectArea.geometryTrigonometry.displayName
                            )
                        )
                    }
                }
            } else {
                Text("Loading progress...")
            }
        }
        .task {
            guard let userId = viewModel.userSession?.uid else {
                print("User Id is nil or empty in Donut chart")
                return
            }
            
            // Fetch the user progress
            do {
                // FIXED: Changed quizViewModel to viewModel (AuthViewModel) to correctly access the fetch function
                if let fetchedUserProgress = try await viewModel.fetchUserProgress(forUserID: userId) {
                    quizViewModel.userProgress = fetchedUserProgress
                } else {
                    print("No user progress available to show for donut chart")
                }
            } catch {
                print("Error fetching user progress for donut chart: \(error.localizedDescription)")
            }
        }
    }
}

// Extend SubjectArea to have a displayName for use in the chart
extension SubjectArea {
    var displayName: String {
        switch self {
        case .algebra:
            return "Algebra"
        case .advancedMath:
            return "Advanced Math"
        case .problemSolvingDataAnalysis:
            return "Problem Solving & Data Analysis"
        case .geometryTrigonometry:
            return "Geometry & Trigonometry"
        }
    }
}

#Preview {
    UserProgressPieChart()
        .environment(AuthViewModel())
        .environment(QuizViewModel(authViewModel: AuthViewModel()))
}
