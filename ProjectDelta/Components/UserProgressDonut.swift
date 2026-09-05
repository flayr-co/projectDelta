import SwiftUI
import Charts

struct UserProgressPieChart: View {
    @Environment(AuthViewModel.self) var viewModel
    @Environment(TestSessionViewModel.self) var testSessionVM // Updated environment injection
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            if let userProgress = testSessionVM.userProgress { // Updated reference
                let dynamicSubjects = Array(userProgress.progress.keys).sorted()
                let chartColors: [Color] = [.cyan, .purple, .orange, .green, .pink, .indigo, .mint, .yellow, .red, .teal]
                
                let totalCorrect = dynamicSubjects.reduce(0) { $0 + (userProgress.progress[$1]?.questionsCorrect ?? 0) }
                let totalAttempted = dynamicSubjects.reduce(0) { $0 + (userProgress.progress[$1]?.questionsAttempted ?? 0) }
                
                if totalAttempted == 0 {
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
                    HStack(spacing: 24) {
                        Chart {
                            ForEach(Array(dynamicSubjects.enumerated()), id: \.element) { index, subjectName in
                                if let progressData = userProgress.progress[subjectName], progressData.questionsAttempted > 0 {
                                    SectorMark(
                                        angle: .value("Correct", progressData.questionsCorrect),
                                        innerRadius: .ratio(0.65),
                                        angularInset: 2.0
                                    )
                                    .cornerRadius(4)
                                    .foregroundStyle(chartColors[index % chartColors.count])
                                }
                            }
                        }
                        .chartLegend(.hidden)
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
                        
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(dynamicSubjects.enumerated()), id: \.element) { index, subjectName in
                                let progressData = userProgress.progress[subjectName] ?? SubjectProgress(questionsAttempted: 0, questionsCorrect: 0)
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(chartColors[index % chartColors.count])
                                        .frame(width: 10, height: 10)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(subjectName)
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
        .task {
            await loadOrCreateProgress()
        }
    }
    
    private func loadOrCreateProgress() async {
        guard let userId = viewModel.userSession?.uid else { return }
        do {
            if let fetchedUserProgress = try await viewModel.fetchUserProgress(forUserID: userId) {
                testSessionVM.userProgress = fetchedUserProgress // Updated reference
            } else {
                try await viewModel.createUserProgress(userId: userId)
                if let refetched = try await viewModel.fetchUserProgress(forUserID: userId) {
                    testSessionVM.userProgress = refetched // Updated reference
                }
            }
        } catch {
            print("Progress structural ledger generation requested: \(error.localizedDescription)")
            try? await viewModel.createUserProgress(userId: userId)
            if let refetched = try? await viewModel.fetchUserProgress(forUserID: userId) {
                testSessionVM.userProgress = refetched // Updated reference
            }
        }
    }
}
