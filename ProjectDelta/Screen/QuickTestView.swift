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
        Group {
            #if os(macOS)
            macOSLayout
            #else
            iOSLayout
            #endif
        }
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
        .task {
            quizViewModel.fetchSubtopicTest(for: subject, subtopic: subtopic)
        }
        .navigationTitle(subtopic ?? subject)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                }
            }
        }
    }

    // MARK: - DESKTOP LAYOUT (macOS)
    #if os(macOS)
    private var macOSLayout: some View {
        ZStack {
            Color.platformSystemGroupedBackground.ignoresSafeArea()
            
            if quizViewModel.isGeneratingQuiz {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Analyzing curriculum...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else if quizViewModel.isQuizComplete {
                quizEndView
            } else if !quizViewModel.questions.isEmpty {
                VStack(spacing: 0) {
                    // Header Status Bar
                    HStack {
                        Text(subtopic ?? subject)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Question \(currentQuestionIndex + 1) / \(quizViewModel.questions.count)")
                            .font(.system(.body, design: .rounded, weight: .bold))
                    }
                    .padding(24)
                    .background(Color.platformSystemBackground)
                    .overlay(Rectangle().frame(height: 1).foregroundColor(Color.primary.opacity(0.1)), alignment: .bottom)
                    
                    ScrollView(showsIndicators: false) {
                        questionContentPage(for: currentQuestionIndex)
                            .padding(.top, 40)
                            .padding(.bottom, 100)
                    }
                    
                    // Desktop Navigation Bar
                    HStack {
                        Button("Previous") { withAnimation { currentQuestionIndex -= 1 } }
                            .disabled(currentQuestionIndex == 0)
                            .controlSize(.large)
                        
                        Spacer()
                        
                        if currentQuestionIndex < quizViewModel.questions.count - 1 {
                            Button("Next") { withAnimation { currentQuestionIndex += 1 } }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                        } else {
                            Button("Submit Test") {
                                Task { await quizViewModel.finishQuiz(subjectId: subject, subtopic: subtopic ?? subject) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.large)
                        }
                    }
                    .padding(24)
                    .background(Color.platformSystemBackground)
                    .overlay(Rectangle().frame(height: 1).foregroundColor(Color.primary.opacity(0.1)), alignment: .top)
                }
            } else {
                Text("No questions found.")
                    .foregroundColor(.secondary)
            }
        }
    }
    #endif

    // MARK: - MOBILE LAYOUT (iOS)
    #if os(iOS)
    private var iOSLayout: some View {
        VStack(spacing: 0) {
            if quizViewModel.isGeneratingQuiz {
                Spacer()
                ProgressView("Analyzing curriculum...")
                    .tint(colorScheme == .dark ? .cyan : .blue)
                Spacer()
            } else if quizViewModel.isQuizComplete {
                quizEndView
            } else if !quizViewModel.questions.isEmpty {
                ZStack(alignment: .bottom) {
                    TabView(selection: $currentQuestionIndex) {
                        ForEach(0..<quizViewModel.questions.count, id: \.self) { index in
                            questionContentPage(for: index)
                                .tag(index)
                                .padding(.bottom, 180)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    bottomNavigationBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            } else {
                Spacer()
                Text("No questions found for this test.")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
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
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 110)
    }
    #endif

    // MARK: - SHARED COMPONENTS
    
    @ViewBuilder
    private func questionContentPage(for index: Int) -> some View {
        ScrollView {
            if index < quizViewModel.questions.count {
                let question = quizViewModel.questions[index]
                
                // Guard clause to prevent ghost questions
                if !question.parsedBlocks.isEmpty {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(question.parsedBlocks) { block in
                                if block.type == QuestionBlockType.text.rawValue {
                                    Text(block.content)
                                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else if block.type == QuestionBlockType.math.rawValue {
                                    LatexView(latex: "$$\n\(block.content.parsedMathToLatex)\n$$")
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.secondary.opacity(0.05))
                                        .cornerRadius(12)
                                } else if block.type == QuestionBlockType.graph.rawValue {
                                    InlineGraphRenderer(graphString: block.content)
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                        .padding(32)
                        .background(Color.platformSystemBackground)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 5)
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                        .padding(.horizontal, 20)

                        VStack(spacing: 16) {
                            let currentOptions = question.options
                            let qId = question.id ?? ""
                            let selectedIndex = quizViewModel.userAnswers[qId]
                            
                            ForEach(currentOptions.indices, id: \.self) { optIndex in
                                Button {
                                    quizViewModel.selectAnswer(for: qId, optionIndex: optIndex)
                                } label: {
                                    HStack {
                                        Text(currentOptions[optIndex])
                                            .multilineTextAlignment(.leading)
                                            .foregroundColor(selectedIndex == optIndex ? .white : .primary)
                                        Spacer()
                                        if selectedIndex == optIndex {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding()
                                    .background(selectedIndex == optIndex ? Color.accentColor : Color.secondary.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                    #if os(macOS)
                    .frame(maxWidth: 800)
                    .frame(maxWidth: .infinity, alignment: .center)
                    #endif
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var quizEndView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Test Result")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                
                if let snapshot = quizViewModel.currentSnapshot {
                    Text("\(snapshot.score) / \(snapshot.totalQuestions)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(snapshot.score > (snapshot.totalQuestions / 2) ? .green : .orange)
                    
                    VStack(spacing: 16) {
                        ForEach(snapshot.questionResults) { result in
                            VStack(alignment: .leading, spacing: 12) {
                                
                                // Adaptive rendering matching the main testing UI
                                if let matchedQuestion = quizViewModel.questions.first(where: { $0.questionText == result.questionText }), !matchedQuestion.parsedBlocks.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(matchedQuestion.parsedBlocks) { block in
                                            if block.type == QuestionBlockType.text.rawValue {
                                                Text(block.content)
                                                    .font(.headline)
                                                    .multilineTextAlignment(.leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            } else if block.type == QuestionBlockType.math.rawValue {
                                                LatexView(latex: "$$\n\(block.content.parsedMathToLatex)\n$$")
                                                    .padding(.vertical, 4)
                                            } else if block.type == QuestionBlockType.graph.rawValue {
                                                InlineGraphRenderer(graphString: block.content)
                                                    .padding(.vertical, 4)
                                            }
                                        }
                                    }
                                } else {
                                    Text(result.questionText)
                                        .font(.headline)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                
                                HStack {
                                    let userAnswerString = result.userSelectedOptionIndex != nil ? result.options[result.userSelectedOptionIndex!] : "No Answer"
                                    Text("Your Answer: \(userAnswerString)")
                                        .foregroundColor(result.isCorrect ? .green : .red)
                                    Spacer()
                                }
                                .font(.subheadline)
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Button("Return to Subject") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(.top)
            .padding(.bottom, 110)
        }
    }
}
