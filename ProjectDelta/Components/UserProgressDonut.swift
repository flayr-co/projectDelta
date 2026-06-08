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
        VStack(spacing: 0) { // Removed outer spacing to let container dictate constraints
            if let userProgress = quizViewModel.userProgress {
                let totalCorrect = SubjectArea.allCases.reduce(0) { $0 + (userProgress.progress[$1]?.questionsCorrect ?? 0) }
                let totalAttempted = SubjectArea.allCases.reduce(0) { $0 + (userProgress.progress[$1]?.questionsAttempted ?? 0) }
                
                if totalAttempted == 0 {
                    // Empty state layout handler if no statistics are recorded yet
                    VStack(spacing: 12) {
                        Spacer()
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.15), lineWidth: 12)
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("No practice questions answered yet")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        // Increased chart size slightly to fill space better
                        .frame(width: 140, height: 140)
                        .overlay {
                            VStack(spacing: 1) {
                                Text("\(totalCorrect)")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundColor(.primary)
                                Text("Correct")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                            }
                        }
                        
                        // Structured interactive color legend block
                        VStack(alignment: .leading, spacing: 10) { // Increased spacing between legend items
                            ForEach(SubjectArea.allCases) { area in
                                let progressData = userProgress.progress[area] ?? SubjectProgress(questionsAttempted: 0, questionsCorrect: 0)
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(colorForSubjectArea(area))
                                        .frame(width: 10, height: 10)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(area.displayName)
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                        Text("\(progressData.questionsCorrect)/\(progressData.questionsAttempted) correct")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .frame(maxHeight: .infinity)
                }
            } else {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(.blue)
                        .scaleEffect(1.2)
                    Text("Loading metrics...")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // Removed the hardcoded padding, background, overlay, and shadow.
        // It now inherits its bounds and styling strictly from the parent MetricsCarouselView card.
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
