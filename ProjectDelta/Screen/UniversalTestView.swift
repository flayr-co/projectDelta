//
//  UniversalTestView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseFirestore
import Combine

struct UniversalTestView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(TestSessionViewModel.self) var testViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @State private var buttonTapped = false
    @State private var currentQuestionIndex = 0
    @State private var selectedQuestionIndex = 0
    @State private var isSubmitting: Bool = false
    @State private var showAdminEditor = false
    
    @State private var timeRemaining: Int = 300
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var mode: TestMode
    
    // Dynamic theme for UI consistency across light/dark modes
    var themeColor: Color { colorScheme == .dark ? .teal : .blue }

    var body: some View {
        Group {
            #if os(macOS)
            macOSLayout
            #else
            iOSLayout
            #endif
        }
        .background(colorScheme == .dark ? Color.customDarkGray : Color.platformSystemGroupedBackground)
        .navigationBarBackButtonHidden(true)
        #if os(macOS)
        .toolbar(.hidden, for: .windowToolbar)
        #endif
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let role = authViewModel.currentUser?.role, (role == .teacher || role == .parent) {
                    Button(action: { showAdminEditor = true }) {
                        Image(systemName: "pencil.and.list.clipboard")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(themeColor)
                    }
                }
            }
        }
        #endif
        #if os(macOS)
        .sheet(isPresented: $showAdminEditor) {
            AdminTestManagerView(
                subjectName: mode.subjectName,
                lessonName: mode.subtopicName ?? "",
                existingTestId: testViewModel.questions.first?.testId
            )
        }
        #else
        .fullScreenCover(isPresented: $showAdminEditor) {
            AdminTestManagerView(
                subjectName: mode.subjectName,
                lessonName: mode.subtopicName ?? "",
                existingTestId: testViewModel.questions.first?.testId
            )
        }
        #endif
        .task {
            if !mode.isTimed {
                buttonTapped = true
                testViewModel.fetchTest(mode: mode)
            }
            await fetchUserProgress()
        }
        .onReceive(timer) { _ in
            handleTimerTick()
        }
    }
    
    // MARK: - TIMER LOGIC
    private func handleTimerTick() {
        guard mode.isTimed, buttonTapped, !testViewModel.isQuizComplete, !testViewModel.isGeneratingQuiz, !testViewModel.questions.isEmpty else { return }
        if timeRemaining > 0 { timeRemaining -= 1 } else if !isSubmitting {
            isSubmitting = true
            Task {
                await testViewModel.finishTest(mode: mode)
                isSubmitting = false
            }
        }
    }
    
    private var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - DESKTOP LAYOUT (macOS)
    #if os(macOS)
    private var macOSLayout: some View {
        ZStack(alignment: .top) {
            Color.platformSystemGroupedBackground.ignoresSafeArea()
            
            if mode.isTimed && !buttonTapped {
                macOSIntroView
                    .frame(maxHeight: .infinity)
            } else if testViewModel.isGeneratingQuiz {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Analyzing curriculum...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else if testViewModel.isQuizComplete {
                quizEndView
                    .frame(maxHeight: .infinity)
            } else if !testViewModel.questions.isEmpty {
                VStack(spacing: 0) {
                    macOSHeader
                        .zIndex(1)
                    
                    QuestionContentPage(index: currentQuestionIndex, mode: mode, themeColor: themeColor)
                }
                
                VStack {
                    Spacer()
                    macOSBottomNavigationBar
                }
                .zIndex(2)
            } else {
                Text("No questions found.")
                    .foregroundColor(.secondary)
                    .frame(maxHeight: .infinity)
            }
        }
    }
    
    private var macOSHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            }
            .buttonStyle(.plain)

            Spacer()
            
            HStack(spacing: 12) {
                Text(mode.subtopicName ?? mode.subjectName)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(.secondary)
                
                if mode.isTimed {
                    Divider().frame(height: 16)
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                        Text(timeString)
                            .monospacedDigit()
                    }
                    .foregroundColor(timeRemaining <= 60 ? .red : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(timeRemaining <= 60 ? Color.red.opacity(0.1) : Color.primary.opacity(0.05))
                    .cornerRadius(8)
                }
                
                Divider().frame(height: 16)
                
                Text("Question \(currentQuestionIndex + 1) of \(testViewModel.questions.count)")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .monospacedDigit()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 10, y: 4)

            Spacer()

            if let role = authViewModel.currentUser?.role, (role == .teacher || role == .parent) {
                Button(action: { showAdminEditor = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil.and.list.clipboard")
                        Text("Edit")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(themeColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 80, height: 1)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
    }
    
    private var macOSBottomNavigationBar: some View {
        HStack(spacing: 20) {
            Button(action: { withAnimation { currentQuestionIndex -= 1 } }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(currentQuestionIndex == 0 ? .gray.opacity(0.3) : .primary)
                    .frame(width: 54, height: 54)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(currentQuestionIndex == 0)

            Spacer()
            
            Menu {
                Picker("Jump to Question", selection: Binding(get: { currentQuestionIndex }, set: { newValue in withAnimation { currentQuestionIndex = newValue } })) {
                    ForEach(0..<testViewModel.questions.count, id: \.self) { index in Text("Question \(index + 1)").tag(index) }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                    Text("Jump")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 100)

            Spacer()

            if currentQuestionIndex < testViewModel.questions.count - 1 {
                Button(action: { withAnimation { currentQuestionIndex += 1 } }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 54, height: 54)
                        .background(themeColor)
                        .clipShape(Circle())
                        .shadow(color: themeColor.opacity(0.4), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: {
                    isSubmitting = true
                    Task {
                        await testViewModel.finishTest(mode: mode)
                        isSubmitting = false
                    }
                }) {
                    HStack {
                        Text(isSubmitting ? "..." : "Turn In")
                        Image(systemName: "paperplane.fill")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(themeColor)
                    .clipShape(Capsule())
                    .shadow(color: themeColor.opacity(0.4), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
        .frame(maxWidth: 864)
    }
    
    private var macOSIntroView: some View {
        VStack(spacing: 32) {
            Image(systemName: "timer")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(themeColor)
                .shadow(color: themeColor.opacity(0.3), radius: 10, y: 5)
            
            VStack(spacing: 8) {
                Text(mode.subtopicName ?? "General \(mode.subjectName)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(.secondary)
                Text("Ready to test your knowledge?")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                Text("5 Minute Timed Session • Challenging Questions")
                    .font(.system(.title3, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Button {
                withAnimation(.easeInOut(duration: 0.5)) {
                    buttonTapped = true
                    timeRemaining = 300
                }
                testViewModel.fetchTest(mode: mode)
            } label: {
                Text("Start Assessment")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .padding(.horizontal, 48)
                    .padding(.vertical, 20)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeColor)
            .controlSize(.large)
            .clipShape(Capsule())
            .shadow(color: themeColor.opacity(0.3), radius: 15, y: 8)
        }
    }
    #endif

    // MARK: - MOBILE LAYOUT (iOS)
    #if os(iOS)
    private var iOSLayout: some View {
        VStack(spacing: 0) {
            if mode.isTimed && !buttonTapped {
                introView
            } else if testViewModel.isGeneratingQuiz {
                Spacer()
                ProgressView("Analyzing curriculum...")
                    .tint(themeColor)
                Spacer()
            } else if testViewModel.isQuizComplete {
                quizEndView
            } else if !testViewModel.questions.isEmpty {
                ZStack(alignment: .top) {
                    TabView(selection: $currentQuestionIndex) {
                        ForEach(0..<testViewModel.questions.count, id: \.self) { index in
                            QuestionContentPage(index: index, mode: mode, themeColor: themeColor)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: currentQuestionIndex) { _, newValue in
                        if selectedQuestionIndex != newValue { selectedQuestionIndex = newValue }
                    }
                    
                    if mode.isTimed {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                            Text(timeString).monospacedDigit()
                        }
                        .font(.subheadline.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .foregroundColor(timeRemaining <= 60 ? .red : .primary)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    bottomNavigationBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            } else {
                Spacer()
                Text("No questions found.")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
    
    private var introView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 60))
                    .foregroundStyle(themeColor)
                
                Text(mode.subtopicName ?? "General \(mode.subjectName)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Take the quiz in the time given")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text("5 Minute Session")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(themeColor)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.5)) { buttonTapped = true; timeRemaining = 300 }
                testViewModel.fetchTest(mode: mode)
            }) {
                Text("Start Now")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(themeColor)
                    .cornerRadius(16)
                    .shadow(color: themeColor.opacity(0.3), radius: 10, y: 5)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    private var bottomNavigationBar: some View {
        HStack {
            Button(action: { if currentQuestionIndex > 0 { withAnimation { currentQuestionIndex -= 1 } } }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(currentQuestionIndex == 0 ? .gray.opacity(0.3) : .primary)
                    .frame(width: 44, height: 44)
            }
            .disabled(currentQuestionIndex == 0)
            
            Spacer()
            
            Menu {
                Picker("Jump to Question", selection: Binding(get: { currentQuestionIndex }, set: { newValue in withAnimation { currentQuestionIndex = newValue } })) {
                    ForEach(0..<testViewModel.questions.count, id: \.self) { index in Text("Question \(index + 1)").tag(index) }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("\(currentQuestionIndex + 1) of \(testViewModel.questions.count)")
                        .font(.subheadline.monospacedDigit())
                        .fontWeight(.bold)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.15))
                .clipShape(Capsule())
            }
            
            Spacer()
            
            let isLastQuestion = currentQuestionIndex == testViewModel.questions.count - 1
            if !isLastQuestion {
                Button(action: { withAnimation { currentQuestionIndex += 1 } }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
            } else {
                Button(action: {
                    isSubmitting = true
                    Task { await testViewModel.finishTest(mode: mode); isSubmitting = false }
                }) {
                    Text(isSubmitting ? "..." : "Turn In")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(themeColor)
                        .clipShape(Capsule())
                        .shadow(color: themeColor.opacity(0.3), radius: 4, y: 2)
                }
                .disabled(isSubmitting)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Capsule().fill(.ultraThinMaterial).shadow(color: .black.opacity(0.1), radius: 10, y: 4))
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    #endif

    // MARK: - SHARED COMPONENTS

    private var quizEndView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundColor(themeColor)
                    .padding(.top, 40)
                
                if case .practice(_, _, _) = mode {
                    Text("Practice Completed")
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                } else {
                    Text("Test Result")
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                }
                
                if let snapshot = testViewModel.currentSnapshot {
                    Text("\(snapshot.score) / \(snapshot.totalQuestions)")
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundColor(snapshot.score > (snapshot.totalQuestions / 2) ? .green : .orange)
                    
                    VStack(spacing: 16) {
                        ForEach(snapshot.questionResults) { result in
                            VStack(alignment: .leading, spacing: 12) {
                                if let matchedQuestion = testViewModel.questions.first(where: { $0.questionText == result.questionText }), !matchedQuestion.parsedBlocks.isEmpty {
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
                                                InlineGraphRenderer(graphString: block.content, themeColor: themeColor)
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
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .font(.subheadline)
                            }
                            .padding()
                            .background(Color.platformSystemBackground)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(themeColor)
                        .controlSize(.large)
                        .clipShape(Capsule())
                        .padding(.top, 24)
                }
            }
            .padding(.bottom, 60)
        }
    }
    
    private func fetchUserProgress() async {
        guard let userId = authViewModel.currentUser?.id, !userId.isEmpty else { return }
        let db = Firestore.firestore()
        do {
            let document = try await db.collection("UserProgress").document(userId).getDocument()
            if let progress = try? document.data(as: UserProgress.self) { testViewModel.userProgress = progress }
        } catch { print("Failed to fetch user progress: \(error.localizedDescription)") }
    }
}

// MARK: - SHARED COMPONENTS
struct QuestionContentPage: View {
    let index: Int
    let mode: TestMode
    let themeColor: Color
    
    @Environment(TestSessionViewModel.self) var testViewModel
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            if index < testViewModel.questions.count {
                IsolatedQuestionCard(
                    question: testViewModel.questions[index],
                    themeColor: themeColor,
                    mode: mode
                )
                .padding(.top, mode.isTimed ? 64 : 40)
                .padding(.bottom, 140)
            }
        }
    }
}

struct IsolatedQuestionCard: View {
    let question: Question
    let themeColor: Color
    let mode: TestMode
    
    @Environment(TestSessionViewModel.self) var testViewModel
    
    @State private var isHintExpanded: Bool = false
    @State private var isFeedbackExpanded: Bool = false
    @State private var hoveredOption: Int? = nil
    
    var body: some View {
        let qId = question.id ?? UUID().uuidString
        // Pulling the selected answer purely locally stops the parent View from redrawing
        let selectedIndex = testViewModel.userAnswers[qId]
        
        VStack(alignment: .leading, spacing: 32) {
            
            // 1. Question Canvas
            if !question.parsedBlocks.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(question.parsedBlocks) { block in
                        if block.type == QuestionBlockType.text.rawValue {
                            Text(block.content)
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if block.type == QuestionBlockType.math.rawValue {
                            LatexView(latex: "$$\n\(block.content.parsedMathToLatex)\n$$")
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(16)
                        } else if block.type == QuestionBlockType.graph.rawValue {
                            InlineGraphRenderer(graphString: block.content, themeColor: themeColor)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(32)
                .background(Color.platformSystemBackground)
                .cornerRadius(24)
                .shadow(color: .black.opacity(0.04), radius: 20, y: 10)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.05), lineWidth: 1))
            }
            
            // 2. Animated Hint & Feedback
            VStack(spacing: 16) {
                if let hint = question.hint, !hint.isEmpty {
                    expandableSection(title: "Hint", icon: "lightbulb", color: .yellow, isExpanded: $isHintExpanded, content: hint)
                }
                
                if case .practice = mode, let feedback = question.feedback, !feedback.isEmpty {
                    expandableSection(title: "Step-by-Step Breakdown", icon: "text.book.closed.fill", color: themeColor, isExpanded: $isFeedbackExpanded, content: feedback)
                }
            }
            
            // 3. Tactile Multiple Choice Options
            VStack(spacing: 16) {
                ForEach(question.options.indices, id: \.self) { optIndex in
                    let isSelected = selectedIndex == optIndex
                    let isHovered = hoveredOption == optIndex
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            testViewModel.selectAnswer(for: qId, optionIndex: optIndex)
                        }
                    }) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(isSelected ? themeColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 6 : 2)
                                    .frame(width: 24, height: 24)
                                
                                if isSelected {
                                    Circle()
                                        .fill(themeColor)
                                        .frame(width: 12, height: 12)
                                }
                            }
                            
                            Text(question.options[optIndex])
                                .multilineTextAlignment(.leading)
                                .foregroundColor(isSelected ? themeColor : .primary)
                                .font(.system(.title3, design: .rounded, weight: isSelected ? .bold : .medium))
                            
                            Spacer()
                        }
                        .padding(20)
                        .contentShape(Rectangle())
                        .background(isSelected ? themeColor.opacity(0.05) : (isHovered ? Color.secondary.opacity(0.05) : Color.platformSystemBackground))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? themeColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(color: isSelected ? themeColor.opacity(0.15) : .clear, radius: 10, y: 4)
                        .scaleEffect(isSelected ? 1.02 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            hoveredOption = hovering ? optIndex : nil
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        #if os(macOS)
        .frame(maxWidth: 800)
        .frame(maxWidth: .infinity, alignment: .center)
        #endif
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHintExpanded)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFeedbackExpanded)
    }
    
    @ViewBuilder
    private func expandableSection(title: String, icon: String, color: Color, isExpanded: Binding<Bool>, content: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                isExpanded.wrappedValue.toggle()
            }) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                }
                .padding(20)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded.wrappedValue {
                Divider().padding(.horizontal, 20)
                ExampleView(text: content, themeColor: themeColor)
                    .padding(20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.platformSystemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 10, y: 5)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
    }
}
