//
//  QuickTestView.swift
//  ProjectDelta
//
//  Created by Jake Meissner.
//

import SwiftUI
import FirebaseFirestore

struct QuickTestView: View {
    @Environment(AuthViewModel.self) var viewModel
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @State private var currentQuestionIndex = 0
    @State private var showUIControls: Bool = true
    
    var subject: String
    var subtopic: String? = nil
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.customDarkGray : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if showUIControls { headerView }
                
                if quizViewModel.isGeneratingQuiz {
                    Spacer()
                    ProgressView("Analyzing curriculum...")
                    Spacer()
                } else if quizViewModel.isQuizComplete {
                    quizEndView
                } else if !quizViewModel.questions.isEmpty {
                    TabView(selection: $currentQuestionIndex) {
                        ForEach(0..<quizViewModel.questions.count, id: \.self) { index in
                            questionContentPage(for: index)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !quizViewModel.isQuizComplete && !quizViewModel.questions.isEmpty && showUIControls {
                testNavigationControls
            }
        }
        .task {
            quizViewModel.fetchSubtopicTest(for: subject, subtopic: subtopic)
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "arrow.left").foregroundColor(.red).bold()
            }
            Text(subtopic ?? subject).font(.headline).bold()
            Spacer()
        }.padding()
    }

    private func questionContentPage(for index: Int) -> some View {
        ScrollView {
            if index < quizViewModel.questions.count {
                let question = quizViewModel.questions[index]
                let qId = question.id ?? ""
                let selectedIndex = quizViewModel.userAnswers[qId]
                
                VStack(alignment: .leading, spacing: 24) {
                    Text(question.questionText)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .padding()

                    VStack(spacing: 16) {
                        ForEach(Array(question.options.enumerated()), id: \.offset) { optIndex, option in
                            Button {
                                quizViewModel.selectAnswer(for: qId, optionIndex: optIndex)
                            } label: {
                                HStack {
                                    Text(option)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    if selectedIndex == optIndex {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                }
                                .padding()
                                .background(selectedIndex == optIndex ? Color.cyan.opacity(0.2) : Color.gray.opacity(0.1))
                                .cornerRadius(12)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal)
                }
            }
        }
    }

    private var quizEndView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Test Result")
                    .font(.title)
                    .bold()
                
                if let snapshot = quizViewModel.currentSnapshot {
                    Text("\(snapshot.score) / \(snapshot.totalQuestions)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(snapshot.score > (snapshot.totalQuestions / 2) ? .green : .orange)
                    
                    VStack(spacing: 16) {
                        ForEach(snapshot.questionResults) { result in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(result.questionText)
                                    .font(.headline)
                                
                                HStack {
                                    let userAnswerString = result.userSelectedOptionIndex != nil ? result.options[result.userSelectedOptionIndex!] : "No Answer"
                                    Text("Your Answer: \(userAnswerString)")
                                        .foregroundColor(result.isCorrect ? .green : .red)
                                    Spacer()
                                    if !result.isCorrect {
                                        Text("Correct: \(result.options[result.correctOptionIndex])")
                                            .foregroundColor(.green)
                                    }
                                }
                                .font(.subheadline)
                                
                                Divider()
                                
                                Text("Feedback:")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.secondary)
                                Text(result.feedback)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    ProgressView("Processing results...")
                }
                
                Button("Return to Subject") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.vertical)
            }
            .padding(.top)
        }
    }

    private var testNavigationControls: some View {
        HStack {
            Button("Back") {
                if currentQuestionIndex > 0 { currentQuestionIndex -= 1 }
            }
            .disabled(currentQuestionIndex == 0)
            
            Spacer()
            
            let isLastQuestion = currentQuestionIndex == quizViewModel.questions.count - 1
            let currentQuestionId = quizViewModel.questions.indices.contains(currentQuestionIndex) ? (quizViewModel.questions[currentQuestionIndex].id ?? "") : ""
            let hasAnswered = quizViewModel.userAnswers[currentQuestionId] != nil
            
            Button(isLastQuestion ? "Submit" : "Next") {
                if isLastQuestion {
                    Task {
                        await quizViewModel.finishQuiz(subjectId: subject, subtopic: subtopic ?? subject)
                    }
                } else {
                    withAnimation {
                        currentQuestionIndex += 1
                    }
                }
            }
            .disabled(!hasAnswered)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}
