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
                        let dynamicSubjects = Array(userProgress.progress.keys).sorted()
                        let chartColors: [Color] = [.cyan, .purple, .orange, .green, .pink, .indigo, .mint, .yellow, .red, .teal]
                        
                        ForEach(Array(dynamicSubjects.enumerated()), id: \.element) { index, subjectName in
                            let progressData = userProgress.progress[subjectName] ?? SubjectProgress(questionsAttempted: 0, questionsCorrect: 0)
                            let color = chartColors[index % chartColors.count]
                            
                            subjectProgressRow(subjectName: subjectName, progress: progressData, color: color)
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
    private func subjectProgressRow(subjectName: String, progress: SubjectProgress, color: Color) -> some View {
        let accuracy = progress.questionsAttempted > 0 ? Double(progress.questionsCorrect) / Double(progress.questionsAttempted) : 0.0
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(subjectName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(Int(accuracy * 100))% Accuracy")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            // Layout Track progress bar meter
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
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
}
