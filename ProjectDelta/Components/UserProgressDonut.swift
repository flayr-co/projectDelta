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
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            if let userProgress = quizViewModel.userProgress {
                let totalCorrect = SubjectArea.allCases.reduce(0) { $0 + (userProgress.progress[$1]?.questionsCorrect ?? 0) }
                let totalAttempted = SubjectArea.allCases.reduce(0) { $0 + (userProgress.progress[$1]?.questionsAttempted ?? 0) }
                
                if totalAttempted == 0 {
                    // Empty state layout handler if no statistics are recorded yet
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 12)
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("No practice questions answered yet")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                } else {
                    // Comprehensive multi-subject analytics rendering
                    HStack(spacing: 24) {
                        Chart {
                            ForEach(SubjectArea.allCases) { area in
                                if let progressData = userProgress.progress[area], progressData.questionsAttempted > 0 {
                                    SectorMark(
                                        angle: .value("Correct", progressData.questionsCorrect),
                                        innerRadius: .ratio(0.65),
                                        angularInset: 2.0
                                    )
                                    .cornerRadius(4)
                                    .foregroundStyle(by: .value("Subject", area.displayName))
                                }
                            }
                        }
                        .chartLegend(.hidden)
                        .chartForegroundStyleScale([
                            SubjectArea.algebra.displayName: Color.cyan,
                            SubjectArea.advancedMath.displayName: Color.purple,
                            SubjectArea.problemSolvingDataAnalysis.displayName: Color.orange,
                            SubjectArea.geometryTrigonometry.displayName: Color.green
                        ])
                        .frame(width: 130, height: 130)
                        .overlay {
                            VStack(spacing: 1) {
                                Text("\(totalCorrect)")
                                    .font(.system(size: 26, weight: .black, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("Correct")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                            }
                        }
                        
                        // Structured interactive color legend block
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(SubjectArea.allCases) { area in
                                let progressData = userProgress.progress[area] ?? SubjectProgress(questionsAttempted: 0, questionsCorrect: 0)
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(colorForSubjectArea(area))
                                        .frame(width: 8, height: 8)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(area.displayName)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text("\(progressData.questionsCorrect)/\(progressData.questionsAttempted) correct")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.blue)
                    Text("Loading progress metrics...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                    Spacer()
                }
                .padding(.vertical, 24)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.16, green: 0.16, blue: 0.19) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.02), radius: 6, x: 0, y: 3)
        .task {
            await loadOrCreateProgress()
        }
    }
    
    private func loadOrCreateProgress() async {
        guard let userId = viewModel.userSession?.uid else { return }
        do {
            if let fetchedUserProgress = try await viewModel.fetchUserProgress(forUserID: userId) {
                quizViewModel.userProgress = fetchedUserProgress
            } else {
                try await viewModel.createUserProgress(userId: userId)
                if let refetched = try await viewModel.fetchUserProgress(forUserID: userId) {
                    quizViewModel.userProgress = refetched
                }
            }
        } catch {
            print("Progress structural ledger generation requested: \(error.localizedDescription)")
            try? await viewModel.createUserProgress(userId: userId)
            if let refetched = try? await viewModel.fetchUserProgress(forUserID: userId) {
                quizViewModel.userProgress = refetched
            }
        }
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
