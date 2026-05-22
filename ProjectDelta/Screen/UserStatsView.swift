//
//  UserStatsView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 12/6/23.
//

import SwiftUI

struct UserStatsView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Performance Analytics")
                    .font(.largeTitle)
                    .fontWeight(.black)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.top, 16)
                
                UserProgressPieChart()
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Subject Area Breakdown")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                    
                    if let userProgress = quizViewModel.userProgress, !userProgress.progress.isEmpty {
                        ForEach(SubjectArea.allCases) { area in
                            let progressData = userProgress.progress[area] ?? SubjectProgress(questionsAttempted: 0, questionsCorrect: 0)
                            subjectProgressRow(area: area, progress: progressData)
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 12) {
                            Text("No structured progress records found.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if let userID = authViewModel.currentUser?.id {
                                Button {
                                    Task {
                                        try? await authViewModel.createUserProgress(userId: userID)
                                        if let refetched = try? await authViewModel.fetchUserProgress(forUserID: userID) {
                                            quizViewModel.userProgress = refetched
                                        }
                                    }
                                } label: {
                                    Text("Initialize Progress Document")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                }
                                .padding(.horizontal, 32)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 32)
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .background(colorScheme == .dark ? Color.customDarkGray : Color.gray.opacity(0.04))
        .task {
            if let userID = authViewModel.currentUser?.id {
                if let fetched = try? await authViewModel.fetchUserProgress(forUserID: userID) {
                    quizViewModel.userProgress = fetched
                }
            }
        }
    }
    
    @ViewBuilder
    private func subjectProgressRow(area: SubjectArea, progress: SubjectProgress) -> some View {
        let accuracy = progress.questionsAttempted > 0 ? Double(progress.questionsCorrect) / Double(progress.questionsAttempted) : 0.0
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(area.displayName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(accuracy * 100))% Accuracy")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(colorForSubjectArea(area))
            }
            
            // Layout Track progress bar meter
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorForSubjectArea(area))
                        .frame(width: geo.size.width * CGFloat(accuracy), height: 8)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("Answered: \(progress.questionsAttempted)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Correct: \(progress.questionsCorrect)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color(red: 0.16, green: 0.16, blue: 0.19) : .white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04), lineWidth: 1)
        )
    }
    
    private func colorForSubjectArea(_ area: SubjectArea) -> Color {
        switch area {
        case .algebra: return .cyan
        case .advancedMath: return .purple
        case .problemSolvingDataAnalysis: return .orange
        case .geometryTrigonometry: return .green
        }
    }
}

#Preview {
    UserStatsView()
        .environment(AuthViewModel())
        .environment(QuizViewModel(authViewModel: AuthViewModel()))
}
