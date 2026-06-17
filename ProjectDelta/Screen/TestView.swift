//
//  TestView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/10/23.
//

import SwiftUI
import FirebaseFirestore

struct TestView: View {
    @State private var buttonTapped = false
    @State private var currentQuestionIndex = 0
    @State private var quizEnded: Bool = false
    @State private var selectedQuestionIndex: Int = 0
    @State private var isSubmitting: Bool = false
    @State private var isHintExpanded: Bool = false
    
    @Environment(AuthViewModel.self) var viewModel
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var subject: String
    var subtopic: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                macOSLayout
                #else
                iOSLayout
                #endif
            }
            .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
            .task {
                await fetchUserProgress()
            }
        }
    }

    // MARK: - DESKTOP LAYOUT (macOS)
    #if os(macOS)
    private var macOSLayout: some View {
        ZStack {
            if !buttonTapped {
                macOSIntroView
            } else {
                macOSQuizFlow
            }
        }
    }
    
    private var macOSIntroView: some View {
        VStack(spacing: 32) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text(subtopic ?? "General \(subject)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(.secondary)
                
                Text("Ready to test your knowledge?")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                
                Text("5 Minutes • Challenging Questions")
                    .font(.system(.title3, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Button {
                withAnimation(.easeInOut(duration: 0.5)) {
                    buttonTapped.toggle()
                }
                quizViewModel.fetchSubtopicTest(for: subject, subtopic: subtopic)
            } label: {
                Text("Start Assessment")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    private var macOSQuizFlow: some View {
        ZStack {
            if quizViewModel.isGeneratingQuiz {
                ProgressView("Analyzing curriculum...")
            } else if quizEnded {
                quizEndView
            } else if !quizViewModel.questions.isEmpty {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text(subtopic ?? subject)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Spacer()
                        Text("Question \(currentQuestionIndex + 1) / \(quizViewModel.questions.count)")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(Color.platformSystemBackground)
                    
                    ScrollView {
                        questionContentPage(for: currentQuestionIndex)
                            .padding(.top, 24)
                    }
                    
                    // Navigation
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
                                isSubmitting = true
                                Task {
                                    await quizViewModel.finishQuiz(subjectId: subject, subtopic: subtopic ?? subject)
                                    quizEnded = true
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.large)
                        }
                    }
                    .padding(24)
                    .background(Color.platformSystemBackground)
                }
            }
        }
    }
    #endif

    // MARK: - MOBILE LAYOUT (iOS)
    #if os(iOS)
    private var iOSLayout: some View {
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
                ProgressView("Fetching test data...")
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
                .onChange(of: currentQuestionIndex) { _, newValue in
                    if selectedQuestionIndex != newValue {
                        selectedQuestionIndex = newValue
                    }
                }
            } else {
                Spacer()
                Text("No questions available for \(subject).")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
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

    private var footerView: some View {
        HStack {
            if currentQuestionIndex > 0 {
                Button("Previous") {
                    withAnimation { currentQuestionIndex -= 1 }
                }
                .buttonStyle(.bordered)
                .tint(.cyan)
            }
            
            Spacer()
            
            if currentQuestionIndex < quizViewModel.questions.count - 1 {
                Button("Next") {
                    withAnimation { currentQuestionIndex += 1 }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            } else {
                Button("Submit") {
                    isSubmitting = true
                    Task {
                        let dynamicSubtopic = subtopic ?? "All"
                        await quizViewModel.finishQuiz(subjectId: subject, subtopic: dynamicSubtopic)
                        quizEnded = true
                        isSubmitting = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isSubmitting)
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
    }
    #endif

    // MARK: - SHARED COMPONENTS
    
    @ViewBuilder
    private func questionContentPage(for index: Int) -> some View {
        ScrollView {
            if index < quizViewModel.questions.count {
                let question = quizViewModel.questions[index]
                let qId = question.id ?? UUID().uuidString
                
                // Adaptive LaTeX / Graph rendering
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
                        
                        if let hint = question.hint, !hint.isEmpty {
                            DisclosureGroup("Hint", isExpanded: $isHintExpanded) {
                                Text(hint)
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                            }
                            .tint(.cyan)
                        }
                        
                        VStack(spacing: 12) {
                            ForEach(Array(question.options.enumerated()), id: \.offset) { optionIndex, optionText in
                                let isSelected = quizViewModel.userAnswers[qId] == optionIndex
                                
                                Button(action: {
                                    quizViewModel.selectAnswer(for: qId, optionIndex: optionIndex)
                                }) {
                                    HStack {
                                        Text(optionText)
                                            .font(.system(.body, design: .rounded))
                                            .multilineTextAlignment(.leading)
                                            .foregroundColor(isSelected ? .white : .primary)
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.white)
                                        } else {
                                            Circle()
                                                .stroke(Color.secondary, lineWidth: 1)
                                                .frame(width: 20, height: 20)
                                        }
                                    }
                                    .padding()
                                    .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(24)
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
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                
                Text("Quiz Complete!")
                    .font(.system(.title, design: .rounded, weight: .bold))
                
                if let snapshot = quizViewModel.currentSnapshot {
                    Text("Score: \(snapshot.score) / \(snapshot.totalQuestions)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
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
                    
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.top)
            .padding(.bottom, 110)
        }
    }
    
    private func fetchUserProgress() async {
        guard let userId = viewModel.currentUser?.id, !userId.isEmpty else { return }
        let db = Firestore.firestore()
        
        do {
            let document = try await db.collection("UserProgress").document(userId).getDocument()
            if let progress = try? document.data(as: UserProgress.self) {
                quizViewModel.userProgress = progress
            }
        } catch {
            print("Failed to fetch user progress: \(error.localizedDescription)")
        }
    }
    
    private var showUIControls: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }
}
