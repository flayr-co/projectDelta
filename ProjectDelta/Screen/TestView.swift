//
//  TestView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/10/23.
//

import SwiftUI

struct TestView: View {
    @State private var buttonTapped = false
    @State private var currentQuestionIndex = 0
    @State private var quizEnded: Bool = false
    @State private var selectedQuestionIndex: Int = 0
    @State private var showUIControls: Bool = true
    @State private var isSubmitting: Bool = false
    
    @Environment(AuthViewModel.self) var viewModel
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var subject: String
    var subtopic: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.customDarkGray : Color.white)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if !buttonTapped {
                        introView
                    } else {
                        quizViewFlow
                    }
                }
            }
            .task {
                await fetchUserProgress()
            }
            .navigationBarBackButtonHidden(true)
        }
    }

    private var introView: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                        .padding(8)
                }
                Spacer()
            }
            .padding(.top, 8)

            Spacer()
            
            VStack(spacing: 12) {
                Text(subtopic ?? "General \(subject)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Take the quiz in the time given")
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("5 Minutes")
                    .font(.system(size: 20, weight: .semibold))
            }
            .foregroundStyle(LinearGradient(colors: [.cyan, .teal, .mint], startPoint: .top, endPoint: .bottom))
            .padding(.bottom, 30)
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.5)) {
                    buttonTapped.toggle()
                }
                quizViewModel.fetchSubtopicTest(for: subject, subtopic: subtopic)
            }) {
                ZStack {
                    LinearGradient(colors: [.cyan, .teal, .mint], startPoint: .top, endPoint: .bottom)
                        .frame(height: 50)
                        .cornerRadius(10)
                    Text("Start Now")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            Spacer()
        }
    }

    @ViewBuilder
    private var quizViewFlow: some View {
        VStack(spacing: 0) {
            if showUIControls { headerView }

            if quizViewModel.isGeneratingQuiz {
                Spacer()
                ProgressView("Building your test...")
                Spacer()
            } else if quizEnded {
                quizEndView
            } else if !quizViewModel.questions.isEmpty {
                if showUIControls { questionSelector }
                
                TabView(selection: $currentQuestionIndex) {
                    ForEach(0..<quizViewModel.questions.count, id: \.self) { index in
                        questionContentPage(for: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .overlay(alignment: .bottom) {
            if !quizEnded && !quizViewModel.isGeneratingQuiz && !quizViewModel.questions.isEmpty && showUIControls {
                footerView
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text(subtopic ?? subject)
                .font(.headline).bold()
            Spacer()
        }.padding()
    }

    private var questionSelector: some View {
        HStack {
            Menu {
                Picker("Question", selection: $selectedQuestionIndex) {
                    ForEach(0..<quizViewModel.questions.count, id: \.self) { index in
                        Text("Question \(index + 1)").tag(index)
                    }
                }
            } label: {
                Label("Question \(currentQuestionIndex + 1)", systemImage: "chevron.down")
                    .foregroundColor(.cyan)
            }
            .onChange(of: selectedQuestionIndex) { _, newValue in
                withAnimation { currentQuestionIndex = newValue }
            }
            Spacer()
        }.padding(.horizontal)
    }

    private func questionContentPage(for index: Int) -> some View {
        ScrollView {
            // CRITICAL SAFETY CHECK: Prevent index out of range
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
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var quizEndView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)
                Image(systemName: "flag.checkered.circle.fill").font(.system(size: 60)).foregroundColor(.cyan)
                Text("Quiz Complete!").font(.title2).bold()
                
                if let snapshot = quizViewModel.currentSnapshot {
                    Text("Score: \(snapshot.score) / \(snapshot.totalQuestions)").font(.headline)
                    Text("+\(snapshot.score * 10) Points!").font(.title3).bold().foregroundColor(.green)
                    
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
                    .padding(.top, 20)
                    
                } else {
                    ProgressView("Loading Results...")
                }
                
                Button("Finish") { dismiss() }.buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(.bottom, 40)
        }
    }

    private var footerView: some View {
        HStack {
            Button(action: { if currentQuestionIndex > 0 { currentQuestionIndex -= 1 } }) {
                Image(systemName: "chevron.left.circle.fill").font(.system(size: 36))
            }
            .disabled(currentQuestionIndex == 0)

            Spacer()
            
            let currentQuestionId = quizViewModel.questions.indices.contains(currentQuestionIndex) ? (quizViewModel.questions[currentQuestionIndex].id ?? "") : ""
            let hasAnswered = quizViewModel.userAnswers[currentQuestionId] != nil
            
            Button(action: {
                if currentQuestionIndex < quizViewModel.questions.count - 1 {
                    withAnimation {
                        currentQuestionIndex += 1
                    }
                } else {
                    isSubmitting = true
                    Task {
                        await quizViewModel.finishQuiz(subjectId: subject, subtopic: subtopic ?? subject)
                        quizEnded = true
                        isSubmitting = false
                    }
                }
            }) {
                if isSubmitting {
                    ProgressView()
                } else {
                    Image(systemName: currentQuestionIndex < quizViewModel.questions.count - 1 ? "chevron.right.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 36))
                }
            }
            .disabled(!hasAnswered || isSubmitting)
        }
        .padding(.horizontal, 25)
        .padding(.bottom, 30)
    }

    private func fetchUserProgress() async {
        guard let userId = viewModel.currentUser?.id else { return }
        if let progress = try? await viewModel.fetchUserProgress(forUserID: userId) {
            quizViewModel.userProgress = progress
        }
    }
}
