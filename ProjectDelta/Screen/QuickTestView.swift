//
//  QuickTestView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/17/23.
//

import SwiftUI
import FirebaseFirestore

struct QuickTestView: View {
    @Environment(AuthViewModel.self) var viewModel
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @State private var currentQuestionIndex = 0
    @State private var userAnswers: [Int?] = []
    @State private var score: Int = 0
    @State private var quizEnded: Bool = false
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
                } else if quizEnded {
                    quizEndView
                } else if !quizViewModel.questions.isEmpty {
                    TabView(selection: $currentQuestionIndex) {
                        ForEach(0..<quizViewModel.questions.count, id: \.self) { index in
                            questionContentPage(for: index)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: quizViewModel.questions.count) { _, newCount in
                        userAnswers = [Int?](repeating: nil, count: newCount)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !quizEnded && !quizViewModel.questions.isEmpty && showUIControls {
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
                VStack(alignment: .leading, spacing: 24) {
                    Text(quizViewModel.questions[index].questionText)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .padding()

                    VStack(spacing: 16) {
                        ForEach(Array(quizViewModel.questions[index].options.enumerated()), id: \.offset) { optIndex, option in
                            Button {
                                if userAnswers.indices.contains(index) { userAnswers[index] = optIndex }
                            } label: {
                                HStack {
                                    Text(option)
                                    Spacer()
                                    if userAnswers.indices.contains(index), userAnswers[index] == optIndex {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                }
                                .padding()
                                .background(userAnswers.indices.contains(index) && userAnswers[index] == optIndex ? Color.cyan.opacity(0.2) : Color.gray.opacity(0.1))
                                .cornerRadius(12)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal)
                }
            }
        }
    }

    private var quizEndView: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Test Result").font(.title).bold()
            Text("\(score) / \(quizViewModel.questions.count)").font(.largeTitle).bold()
            Button("Return") { dismiss() }.buttonStyle(.borderedProminent)
            Spacer()
        }
        .onAppear {
            Task { await quizViewModel.finishQuiz(score: score) }
        }
    }

    private var testNavigationControls: some View {
        HStack {
            Button("Back") { if currentQuestionIndex > 0 { currentQuestionIndex -= 1 } }.disabled(currentQuestionIndex == 0)
            Spacer()
            Button(currentQuestionIndex < quizViewModel.questions.count - 1 ? "Next" : "Submit") {
                if currentQuestionIndex < quizViewModel.questions.count - 1 {
                    currentQuestionIndex += 1
                } else {
                    calculateScore()
                    quizEnded = true
                }
            }.disabled(userAnswers.indices.contains(currentQuestionIndex) ? userAnswers[currentQuestionIndex] == nil : true)
        }.padding()
    }

    private func calculateScore() {
        score = 0
        for (index, answer) in userAnswers.enumerated() {
            if index < quizViewModel.questions.count {
                if let answer = answer, answer == quizViewModel.questions[index].correctOptionIndex { score += 1 }
            }
        }
    }
}
