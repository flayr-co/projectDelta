//
//  PracticeTestView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct PracticeTestView: View {
    @Environment(AuthViewModel.self) var viewModel
    var practiceTestViewModel: PracticeTestViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @State private var currentQuestionIndex = 0
    @State private var userAnswers: [Int: Int] = [:]
    @State private var score: Int = 0
    @State private var practiceTestEnded: Bool = false
    @State private var selectedQuestionIndex: Int = 0
    
    var lessonID: String
    var practiceTestID: String

    var body: some View {
        VStack(spacing: 0) {
            if !practiceTestEnded && practiceTestViewModel.questions.isEmpty {
                Spacer()
                ProgressView("Loading test...")
                    .tint(colorScheme == .dark ? .cyan : .blue)
                Spacer()
            } else if !practiceTestEnded {
                ZStack(alignment: .bottom) {
                    TabView(selection: $currentQuestionIndex) {
                        ForEach(0..<practiceTestViewModel.questions.count, id: \.self) { index in
                            questionContentPage(for: index)
                                .tag(index)
                                .padding(.bottom, 180)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    if !practiceTestViewModel.questions.isEmpty {
                        bottomNavigationBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            } else {
                testEndView
            }
        }
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
        .task {
            await practiceTestViewModel.fetchPracticeTest(for: lessonID, practiceTestID: practiceTestID)
        }
        .navigationTitle("Practice Test")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - COMPONENTS
    
    private func questionContentPage(for index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Advanced Block Renderer
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(practiceTestViewModel.questions[index].parsedBlocks) { block in
                        if block.type == QuestionBlockType.text.rawValue {
                            Text(block.content)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if block.type == QuestionBlockType.math.rawValue {
                            LatexView(latex: "$$\n\(block.content.parsedMathToLatex)\n$$")
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        } else if block.type == QuestionBlockType.graph.rawValue {
                            InlineGraphRenderer(graphString: block.content)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // Flawless Compiler Option Loop
                VStack(spacing: 16) {
                    let currentOptions = practiceTestViewModel.questions[index].options
                    ForEach(currentOptions.indices, id: \.self) { optIndex in
                        Button {
                            userAnswers[index] = optIndex
                        } label: {
                            optionView(
                                option: currentOptions[optIndex],
                                isSelected: userAnswers[index] == optIndex
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private var bottomNavigationBar: some View {
        HStack {
            Button(action: {
                if currentQuestionIndex > 0 {
                    withAnimation { currentQuestionIndex -= 1 }
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(currentQuestionIndex == 0 ? .gray.opacity(0.3) : (colorScheme == .dark ? .cyan : .blue))
                    .frame(width: 44, height: 44)
            }
            .disabled(currentQuestionIndex == 0)

            Spacer()

            Menu {
                Picker("Jump to Question", selection: Binding(
                    get: { currentQuestionIndex },
                    set: { newValue in withAnimation { currentQuestionIndex = newValue } }
                )) {
                    ForEach(0..<practiceTestViewModel.questions.count, id: \.self) { index in
                        Text("Question \(index + 1)").tag(index)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("\(currentQuestionIndex + 1) of \(practiceTestViewModel.questions.count)")
                        .font(.subheadline.monospacedDigit())
                        .fontWeight(.medium)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.15))
                .clipShape(Capsule())
            }

            Spacer()

            if currentQuestionIndex < practiceTestViewModel.questions.count - 1 {
                Button(action: {
                    withAnimation { currentQuestionIndex += 1 }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .cyan : .blue)
                        .frame(width: 44, height: 44)
                }
            } else {
                Button(action: {
                    postPracticeTestUpdate()
                }) {
                    Text("Turn In")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(colorScheme == .dark ? Color.cyan : Color.blue)
                        .clipShape(Capsule())
                        .shadow(color: (colorScheme == .dark ? Color.cyan : Color.blue).opacity(0.3), radius: 4, y: 2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 110)
    }
    
    private var testEndView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "flag.checkered.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(colorScheme == .dark ? .cyan : .blue)
            
            Text("Practice Test Complete!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Your score is \(score) out of \(practiceTestViewModel.questions.count)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                Button(action: {
                    withAnimation {
                        currentQuestionIndex = 0
                        score = 0
                        practiceTestEnded = false
                        userAnswers.removeAll()
                    }
                }) {
                    Text("Retry")
                        .fontWeight(.semibold)
                        .foregroundColor(colorScheme == .dark ? .cyan : .blue)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: { dismiss() }) {
                    Text("Go Home")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(colorScheme == .dark ? Color.cyan : Color.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .padding(.bottom, 110)
        .frame(maxWidth: .infinity)
    }

    func optionView(option: String, isSelected: Bool) -> some View {
        HStack {
            Text(option)
                .font(.body)
                .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white : .black))
                .padding()
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .padding(.trailing)
            }
        }
        .background(isSelected ? (colorScheme == .dark ? Color.cyan : Color.blue) : Color.gray.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? (colorScheme == .dark ? Color.cyan : Color.blue) : Color.clear, lineWidth: 2)
        )
    }

    private func postPracticeTestUpdate() {
        practiceTestEnded = true
        score = 0
        
        for index in 0..<practiceTestViewModel.questions.count {
            if let answer = userAnswers[index], answer == practiceTestViewModel.questions[index].correctOptionIndex {
                score += 1
            }
        }
        
        Task {
            guard let userId = viewModel.currentUser?.id, !userId.isEmpty else { return }
            
            let totalPointsChange = score * 10 - (practiceTestViewModel.questions.count - score) * 5
            
            await viewModel.updateUserPointsInFirestore(newPoints: (viewModel.currentUser?.points ?? 0) + totalPointsChange)
            await viewModel.storeTodaysPoints(pointsGainedToday: totalPointsChange)
            
            if let currentSubjectArea = practiceTestViewModel.currentSubject?.subjectArea {
                for index in 0..<practiceTestViewModel.questions.count {
                    let questionDocId = practiceTestViewModel.questions[index].id ?? ""
                    let isCorrect = (userAnswers[index] == practiceTestViewModel.questions[index].correctOptionIndex)
                    
                    if !questionDocId.isEmpty {
                        do {
                            try await practiceTestViewModel.updateUserProgressForSubject(
                                userID: userId,
                                subjectArea: currentSubjectArea,
                                answeredCorrectly: isCorrect,
                                questionDocumentID: questionDocId
                            )
                        } catch {
                            print("Failed to update user progress for question \(questionDocId): \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}
