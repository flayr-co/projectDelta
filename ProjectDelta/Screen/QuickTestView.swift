//
//  QuickTestView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseFirestore

struct QuickTestView: View {
    @Environment(AuthViewModel.self) var viewModel
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @State private var currentQuestionIndex = 0
    
    var subject: String
    var subtopic: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            if quizViewModel.isGeneratingQuiz {
                Spacer()
                ProgressView("Analyzing curriculum...")
                    .tint(colorScheme == .dark ? .cyan : .blue)
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
            } else {
                Spacer()
                Text("No questions found for this test.")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
        .task {
            quizViewModel.fetchSubtopicTest(for: subject, subtopic: subtopic)
        }
        .safeAreaInset(edge: .bottom) {
            if !quizViewModel.isQuizComplete && !quizViewModel.questions.isEmpty {
                bottomNavigationBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(subtopic ?? subject)
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

    private func questionContentPage(for index: Int) -> some View {
        ScrollView {
            if index < quizViewModel.questions.count {
                VStack(alignment: .leading, spacing: 24) {
                    
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(quizViewModel.questions[index].parsedBlocks) { block in
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
                        let currentOptions = quizViewModel.questions[index].options
                        let qId = quizViewModel.questions[index].id ?? ""
                        let selectedIndex = quizViewModel.userAnswers[qId]
                        
                        ForEach(currentOptions.indices, id: \.self) { optIndex in
                            Button {
                                quizViewModel.selectAnswer(for: qId, optionIndex: optIndex)
                            } label: {
                                HStack {
                                    Text(currentOptions[optIndex])
                                        .multilineTextAlignment(.leading)
                                        .foregroundColor(selectedIndex == optIndex ? .white : (colorScheme == .dark ? .white : .black))
                                    Spacer()
                                    if selectedIndex == optIndex {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding()
                                .background(selectedIndex == optIndex ? (colorScheme == .dark ? Color.cyan : Color.blue) : Color.gray.opacity(0.15))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedIndex == optIndex ? (colorScheme == .dark ? Color.cyan : Color.blue) : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
            }
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
                    set: { withAnimation { currentQuestionIndex = $0 } }
                )) {
                    ForEach(0..<quizViewModel.questions.count, id: \.self) { index in
                        Text("Question \(index + 1)").tag(index)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("\(currentQuestionIndex + 1) of \(quizViewModel.questions.count)")
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

            let isLastQuestion = currentQuestionIndex == quizViewModel.questions.count - 1
            
            if !isLastQuestion {
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
                    Task {
                        await quizViewModel.finishQuiz(subjectId: subject, subtopic: subtopic ?? subject)
                    }
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
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.05), radius: 5, y: -5)
        )
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
                                if result.questionText.contains("\"type\":\"Text\"") {
                                    Text("Review Question")
                                        .font(.headline)
                                } else {
                                    Text(result.questionText)
                                        .font(.headline)
                                }
                                
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
                                
                                if !result.feedback.isEmpty {
                                    Divider()
                                    Text("Feedback:")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.secondary)
                                    Text(result.feedback)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
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
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Return to Subject")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(colorScheme == .dark ? Color.cyan : Color.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.vertical)
            }
            .padding(.top)
        }
    }
}
