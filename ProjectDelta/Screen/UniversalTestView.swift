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
    
    @AppStorage("hideCustomTabBar") private var hideCustomTabBar: Bool = false
    @State private var isTestActive: Bool = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var mode: TestMode
    
    var themeColor: Color {
        colorScheme == .dark ? Color(red: 0.15, green: 0.85, blue: 0.75) : Color(red: 0.05, green: 0.65, blue: 0.85)
    }

    var body: some View {
        Group {
#if os(macOS)
            macOSLayout
#else
            iOSLayout
#endif
        }
        .background(colorScheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.08) : Color.platformSystemGroupedBackground)
        .navigationBarBackButtonHidden(true)
#if os(macOS)
        .toolbar(.hidden, for: .windowToolbar)
        .sheet(isPresented: $showAdminEditor) {
            AdminTestManagerView(
                subjectName: mode.subjectName,
                lessonName: mode.subtopicName ?? "",
                existingTestId: testViewModel.questions.first?.testId
            )
        }
#else
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
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
        .onAppear {
            isTestActive = true
            hideCustomTabBar = true
        }
        .onDisappear {
            isTestActive = false
            hideCustomTabBar = false
        }
        .onChange(of: hideCustomTabBar) { _, isHidden in
            if isTestActive && !isHidden {
                hideCustomTabBar = true
            }
        }
    }
    
    // MARK: - Timer Logic
    private func handleTimerTick() {
        guard mode.isTimed, buttonTapped, !testViewModel.isQuizComplete, !testViewModel.isGeneratingQuiz, !testViewModel.questions.isEmpty else { return }
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else if !isSubmitting {
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

    // MARK: - macOS Layout
    #if os(macOS)
    private var macOSLayout: some View {
        ZStack(alignment: .top) {
            Color.platformSystemGroupedBackground.ignoresSafeArea()
            
            if mode.isTimed && !buttonTapped {
                macOSIntroView
                    .frame(maxHeight: .infinity)
            } else if testViewModel.isGeneratingQuiz {
                VStack(spacing: 20) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(themeColor)
                    Text("Loading assessment pool...")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
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
                ContentUnavailableView("No Questions Found", systemImage: "doc.questionmark", description: Text("No questions are currently mapped to this module."))
                    .frame(maxHeight: .infinity)
            }
        }
    }
    
    private var macOSHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                }
                .buttonStyle(.plain)

                Spacer()
                
                HStack(spacing: 12) {
                    Text(mode.subtopicName ?? mode.subjectName)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if mode.isTimed {
                        Divider().frame(height: 16)
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                            Text(timeString).monospacedDigit()
                        }
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(timeRemaining <= 60 ? .red : themeColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((timeRemaining <= 60 ? Color.red : themeColor).opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                Spacer()

                if let role = authViewModel.currentUser?.role, (role == .teacher || role == .parent) {
                    Button(action: { showAdminEditor = true }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(themeColor)
                            .frame(width: 40, height: 40)
                            .background(themeColor.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(themeColor.gradient)
                        .frame(width: geo.size.width * CGFloat(currentQuestionIndex + 1) / CGFloat(max(testViewModel.questions.count, 1)))
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: currentQuestionIndex)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 32)
        }
    }
    
    private var macOSBottomNavigationBar: some View {
        HStack(spacing: 16) {
            Button(action: { withAnimation { currentQuestionIndex -= 1 } }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(currentQuestionIndex == 0 ? .secondary.opacity(0.3) : .primary)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(currentQuestionIndex == 0)

            Spacer()
            
            Text("\(currentQuestionIndex + 1) of \(testViewModel.questions.count)")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .padding(.horizontal, 24)
                .frame(height: 50)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)

            Spacer()

            if currentQuestionIndex < testViewModel.questions.count - 1 {
                Button(action: { withAnimation { currentQuestionIndex += 1 } }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(themeColor.gradient)
                        .clipShape(Circle())
                        .shadow(color: themeColor.opacity(0.35), radius: 8, y: 4)
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
                    HStack(spacing: 8) {
                        Text(isSubmitting ? "Submitting..." : "Turn In")
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 50)
                    .background(themeColor.gradient)
                    .clipShape(Capsule())
                    .shadow(color: themeColor.opacity(0.35), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
        .frame(maxWidth: 820)
    }
    
    private var macOSIntroView: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "timer")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundColor(themeColor)
            }
            
            VStack(spacing: 8) {
                Text(mode.subtopicName ?? "General \(mode.subjectName)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(.secondary)
                Text("Timed Assessment")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                Text("5 Minute Session • Instant Diagnostic Breakdown")
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Button {
                withAnimation(.easeInOut(duration: 0.4)) {
                    buttonTapped = true
                    timeRemaining = 300
                }
                testViewModel.fetchTest(mode: mode)
            } label: {
                Text("Begin Exam")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeColor)
            .clipShape(Capsule())
            .shadow(color: themeColor.opacity(0.35), radius: 12, y: 6)
        }
    }
    #endif

    // MARK: - iOS Layout
    #if os(iOS)
    private var iOSLayout: some View {
        VStack(spacing: 0) {
            iOSHeader
                .zIndex(1)
                
            if mode.isTimed && !buttonTapped {
                introView
            } else if testViewModel.isGeneratingQuiz {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(themeColor)
                    Text("Configuring assessment...")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if testViewModel.isQuizComplete {
                quizEndView
            } else if !testViewModel.questions.isEmpty {
                ZStack(alignment: .bottom) {
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
                    
                    bottomNavigationBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            } else {
                Spacer()
                ContentUnavailableView("No Questions Found", systemImage: "doc.questionmark", description: Text("No questions mapped to this module."))
                Spacer()
            }
        }
    }
    
    private var iOSHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 38, height: 38)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()
                
                Text(mode.subtopicName ?? mode.subjectName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                if let role = authViewModel.currentUser?.role, (role == .teacher || role == .parent) {
                    Button(action: { showAdminEditor = true }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(themeColor)
                            .frame(width: 38, height: 38)
                            .background(themeColor.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 38, height: 38)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 12)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(themeColor.gradient)
                        .frame(width: geo.size.width * CGFloat(currentQuestionIndex + 1) / CGFloat(max(testViewModel.questions.count, 1)))
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: currentQuestionIndex)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
        }
        .background(colorScheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.08) : Color.platformSystemGroupedBackground)
    }
    
    private var introView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: "timer")
                        .font(.system(size: 46))
                        .foregroundStyle(themeColor)
                }
                
                Text(mode.subtopicName ?? "General \(mode.subjectName)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text("Timed Assessment")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text("5 minutes to complete all questions.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.4)) {
                    buttonTapped = true
                    timeRemaining = 300
                }
                testViewModel.fetchTest(mode: mode)
            }) {
                Text("Begin Exam")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(themeColor.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: themeColor.opacity(0.3), radius: 12, y: 6)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    private var bottomNavigationBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                if currentQuestionIndex > 0 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentQuestionIndex -= 1
                    }
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(currentQuestionIndex == 0 ? .secondary.opacity(0.25) : .primary)
                    .frame(width: 48, height: 48)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(currentQuestionIndex == 0)
            
            Spacer(minLength: 0)
            
            Menu {
                Picker("Navigate Questions", selection: Binding(
                    get: { currentQuestionIndex },
                    set: { newValue in withAnimation { currentQuestionIndex = newValue } }
                )) {
                    ForEach(0..<testViewModel.questions.count, id: \.self) { index in
                        Text("Question \(index + 1)").tag(index)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("\(currentQuestionIndex + 1) of \(testViewModel.questions.count)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
            }
            .fixedSize(horizontal: true, vertical: false)
            
            Spacer(minLength: 0)
            
            let isLastQuestion = currentQuestionIndex == testViewModel.questions.count - 1
            if !isLastQuestion {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentQuestionIndex += 1
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(themeColor.gradient)
                        .clipShape(Circle())
                        .shadow(color: themeColor.opacity(0.35), radius: 8, y: 3)
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
                    Text(isSubmitting ? "..." : "Turn In")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 48)
                        .background(themeColor.gradient)
                        .clipShape(Capsule())
                        .shadow(color: themeColor.opacity(0.35), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
    #endif

    // MARK: - Results Screen
    private var quizEndView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 40) {
                if let snapshot = testViewModel.currentSnapshot {
                    let percentage = Double(snapshot.score) / Double(max(snapshot.totalQuestions, 1))
                    let percentageInt = Int(percentage * 100)
                    let ringColor = percentage >= 0.8 ? Color.green : (percentage >= 0.6 ? Color.orange : Color.red)
                    let correctCount = snapshot.score
                    let incorrectCount = max(snapshot.totalQuestions - correctCount, 0)
                    
                    // Top Radial Dashboard
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .stroke(Color.primary.opacity(0.06), lineWidth: 16)
                                .frame(width: 170, height: 170)
                            
                            Circle()
                                .trim(from: 0.0, to: CGFloat(percentage))
                                .stroke(
                                    AngularGradient(
                                        colors: [ringColor.opacity(0.5), ringColor],
                                        center: .center,
                                        startAngle: .degrees(-90),
                                        endAngle: .degrees(270)
                                    ),
                                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 170, height: 170)
                                .animation(.spring(response: 1.0, dampingFraction: 0.75).delay(0.15), value: percentage)
                            
                            VStack(spacing: 0) {
                                Text("\(percentageInt)%")
                                    .font(.system(size: 44, weight: .black, design: .rounded))
                                    .foregroundColor(.primary)
                                Text(getLetterGrade(for: percentageInt))
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundColor(ringColor)
                            }
                        }
                        .padding(.top, 28)
                        
                        VStack(spacing: 6) {
                            Text("Assessment Complete")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                            Text("Comprehensive performance overview and solutions.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Performance KPI Row
                        HStack(spacing: 12) {
                            kpiPill(title: "Score", value: "\(correctCount)/\(snapshot.totalQuestions)", icon: "target", color: themeColor)
                            kpiPill(title: "Correct", value: "\(correctCount)", icon: "checkmark.circle.fill", color: .green)
                            kpiPill(title: "Incorrect", value: "\(incorrectCount)", icon: "xmark.circle.fill", color: .red)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Question Diagnostic Review
                    VStack(spacing: 18) {
                        ForEach(Array(snapshot.questionResults.enumerated()), id: \.element.id) { index, result in
                            VStack(alignment: .leading, spacing: 0) {
                                // Question Card Header
                                HStack {
                                    Text("Question \(index + 1)")
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                        .foregroundColor(result.isCorrect ? .green : .red)
                                        .textCase(.uppercase)
                                    Spacer()
                                    HStack(spacing: 5) {
                                        Image(systemName: result.isCorrect ? "checkmark" : "xmark")
                                            .font(.system(size: 11, weight: .black))
                                        Text(result.isCorrect ? "Correct" : "Incorrect")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(result.isCorrect ? .green : .red)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background((result.isCorrect ? Color.green : Color.red).opacity(0.12))
                                    .clipShape(Capsule())
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(Color.primary.opacity(0.02))
                                
                                Divider()
                                
                                // Question Content Canvas
                                VStack(alignment: .leading, spacing: 16) {
                                    if let matched = testViewModel.questions.first(where: { $0.id == result.questionId || $0.questionText == result.questionText }), !matched.parsedBlocks.isEmpty {
                                        VStack(alignment: .leading, spacing: 12) {
                                            ForEach(matched.parsedBlocks) { block in
                                                if block.type == QuestionBlockType.text.rawValue {
                                                    if block.content.contains("$") {
                                                        LatexView(latex: block.content.parsedMathToLatex, isTextMode: true)
                                                            .frame(maxWidth: .infinity, alignment: .leading)
                                                    } else {
                                                        Text(LocalizedStringKey(block.content.parsedInlineMathToMarkdown))
                                                            .font(.system(size: 17, weight: .bold, design: .rounded))
                                                            .foregroundColor(.primary)
                                                            .fixedSize(horizontal: false, vertical: true)
                                                    }
                                                } else if block.type == QuestionBlockType.math.rawValue {
                                                    LatexView(latex: "$$\n\(block.content.parsedMathToLatex)\n$$")
                                                        .frame(maxWidth: .infinity, alignment: .center)
                                                        .padding(.vertical, 8)
                                                        .padding(.horizontal, 12)
                                                        .background(Color.primary.opacity(0.03))
                                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                } else if block.type == QuestionBlockType.graph.rawValue {
                                                    InlineGraphRenderer(graphString: block.content, themeColor: themeColor)
                                                        .frame(height: 180)
                                                }
                                            }
                                        }
                                    } else {
                                        if result.questionText.contains("$") {
                                            LatexView(latex: result.questionText.parsedMathToLatex, isTextMode: true)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        } else {
                                            Text(LocalizedStringKey(result.questionText.parsedInlineMathToMarkdown))
                                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                                .foregroundColor(.primary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    
                                    // User Choice vs Correct Solution
                                    VStack(spacing: 8) {
                                        let userChoice = (result.userSelectedOptionIndex != nil && result.options.indices.contains(result.userSelectedOptionIndex!)) ? result.options[result.userSelectedOptionIndex!] : "No Answer Submitted"
                                        
                                        answerMetricRow(
                                            label: "Your Answer",
                                            text: userChoice,
                                            isCorrect: result.isCorrect,
                                            isUserChoice: true
                                        )
                                        
                                        if !result.isCorrect && result.options.indices.contains(result.correctOptionIndex) {
                                            answerMetricRow(
                                                label: "Correct Solution",
                                                text: result.options[result.correctOptionIndex],
                                                isCorrect: true,
                                                isUserChoice: false
                                            )
                                        }
                                    }
                                    
                                    // Step-by-Step Diagnostic Breakdown
                                    if !result.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "text.book.closed.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(themeColor)
                                                Text("Step-by-Step Breakdown")
                                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                                    .foregroundColor(.primary)
                                                    .textCase(.uppercase)
                                            }
                                            
                                            ProgressiveStepsView(content: result.feedback, themeColor: themeColor)
                                        }
                                        .padding(20)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.primary.opacity(0.02))
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                                        .padding(.top, 8)
                                    }
                                }
                                .padding(20)
                            }
                            .background(Color.platformSystemBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: .black.opacity(0.03), radius: 10, y: 4)
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 20)
#if os(macOS)
                    .frame(maxWidth: 780)
#endif
                    
                    Button(action: { dismiss() }) {
                        HStack(spacing: 8) {
                            Text("Complete Review")
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: 320)
                        .frame(height: 54)
                        .background(themeColor.gradient)
                        .clipShape(Capsule())
                        .shadow(color: themeColor.opacity(0.35), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                }
            }
            .padding(.bottom, 60)
#if os(macOS)
            .frame(maxWidth: .infinity, alignment: .center)
            .safeAreaPadding(.top, 48)
#endif
        }
    }
    
    // MARK: - Helper Views
    @ViewBuilder
    private func kpiPill(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
            }
            .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.platformSystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.02), radius: 6, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
    }
    
    @ViewBuilder
    private func answerMetricRow(label: String, text: String, isCorrect: Bool, isUserChoice: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label + ":")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            
            if text.contains("$") {
                LatexView(latex: text.parsedMathToLatex, isTextMode: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(LocalizedStringKey(text.parsedInlineMathToMarkdown))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(isUserChoice ? (isCorrect ? .green : .red) : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isUserChoice ? (isCorrect ? Color.green.opacity(0.08) : Color.red.opacity(0.08)) : Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func fetchUserProgress() async {
        guard let userId = authViewModel.currentUser?.id, !userId.isEmpty else { return }
        let db = Firestore.firestore()
        do {
            let document = try await db.collection("UserProgress").document(userId).getDocument()
            if let progress = try? document.data(as: UserProgress.self) { testViewModel.userProgress = progress }
        } catch {
            print("Failed to fetch user progress: \(error.localizedDescription)")
        }
    }
    
    private func getLetterGrade(for percentage: Int) -> String {
        switch percentage {
        case 97...100: return "A+"
        case 93...96: return "A"
        case 90...92: return "A-"
        case 87...89: return "B+"
        case 83...86: return "B"
        case 80...82: return "B-"
        case 77...79: return "C+"
        case 73...76: return "C"
        case 70...72: return "C-"
        case 67...69: return "D+"
        case 63...66: return "D"
        case 60...62: return "D-"
        default: return "F"
        }
    }
}

// MARK: - Question Content Page
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
                    index: index,
                    themeColor: themeColor,
                    mode: mode
                )
                .padding(.top, 14)
            }
        }
        #if os(macOS)
        .safeAreaPadding(.bottom, 32)
        #else
        .safeAreaPadding(.bottom, 110)
        #endif
    }
}

// MARK: - Isolated Question Card
struct IsolatedQuestionCard: View {
    let question: Question
    let index: Int
    let themeColor: Color
    let mode: TestMode
    
    @Environment(TestSessionViewModel.self) var testViewModel
    
    @State private var isHintExpanded: Bool = false
    @State private var isFeedbackExpanded: Bool = false
    @State private var hoveredOption: Int? = nil
    @State private var blockInteractionStates: [String: Bool] = [:]
    
    let optionLetters = ["A", "B", "C", "D", "E", "F"]
    
    var body: some View {
        let qId = question.id ?? UUID().uuidString
        let selectedIndex = testViewModel.userAnswers[qId]
        
        #if os(macOS)
        let mainSpacing: CGFloat = 24
        let canvasPadding: CGFloat = 28
        let optionSpacing: CGFloat = 12
        let questionFontSize: CGFloat = 22
        #else
        let mainSpacing: CGFloat = 18
        let canvasPadding: CGFloat = 20
        let optionSpacing: CGFloat = 10
        let questionFontSize: CGFloat = 19
        #endif
        
        VStack(alignment: .leading, spacing: mainSpacing) {
            
            // 1. Primary Problem Canvas
            if !question.parsedBlocks.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(question.parsedBlocks) { block in
                        if block.type == QuestionBlockType.text.rawValue {
                            if block.content.contains("$") {
                                LatexView(latex: block.content.parsedMathToLatex, isTextMode: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(LocalizedStringKey(block.content.parsedInlineMathToMarkdown))
                                    .font(.system(size: questionFontSize, weight: .black, design: .rounded))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else if block.type == QuestionBlockType.math.rawValue {
                            LatexView(latex: "$$\n\(block.content.parsedMathToLatex)\n$$")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .background(Color.primary.opacity(0.03))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            
                            if let caption = block.caption, !caption.isEmpty {
                                Text(LocalizedStringKey(caption.parsedInlineMathToMarkdown))
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                            }
                        } else if block.type == QuestionBlockType.graph.rawValue {
                            let isInteractive = blockInteractionStates[block.id] ?? false
                            
                            ZStack(alignment: .topTrailing) {
                                InlineGraphRenderer(graphString: block.content, themeColor: themeColor)
                                    .padding(.vertical, 6)
                                    .allowsHitTesting(isInteractive)
                                
#if os(iOS)
                                Button {
                                    withAnimation { blockInteractionStates[block.id] = !isInteractive }
                                } label: {
                                    Image(systemName: isInteractive ? "lock.open.fill" : "lock.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(isInteractive ? .white : themeColor)
                                        .padding(8)
                                        .background(isInteractive ? themeColor : Color.platformSecondarySystemBackground)
                                        .clipShape(Circle())
                                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                                }
                                .padding(8)
#endif
                            }
                        }
                    }
                }
                .padding(canvasPadding)
                .background(Color.platformSystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.03), radius: 12, y: 5)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 1))
            }
            
            // 2. Tactile Multiple Choice Options
            VStack(spacing: optionSpacing) {
                ForEach(question.options.indices, id: \.self) { optIndex in
                    let optionText = question.options[optIndex]
                    let isSelected = selectedIndex == optIndex
                    let isHovered = hoveredOption == optIndex
                    let letter = optIndex < optionLetters.count ? optionLetters[optIndex] : "\(optIndex + 1)"
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                            testViewModel.selectAnswer(for: qId, optionIndex: optIndex)
                        }
                    }) {
                        HStack(spacing: 14) {
                            // Letter Identifier Badge
                            Text(letter)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundColor(isSelected ? .white : .secondary)
                                .frame(width: 32, height: 32)
                                .background(isSelected ? themeColor : Color.primary.opacity(0.06))
                                .clipShape(Circle())
                            
                            if optionText.contains("$") {
                                LatexView(latex: optionText.parsedMathToLatex, isTextMode: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(LocalizedStringKey(optionText.parsedInlineMathToMarkdown))
                                    .multilineTextAlignment(.leading)
                                    .foregroundColor(isSelected ? themeColor : .primary)
                                    #if os(macOS)
                                    .font(.system(.title3, design: .rounded, weight: isSelected ? .bold : .semibold))
                                    #else
                                    .font(.system(size: 17, weight: isSelected ? .bold : .semibold, design: .rounded))
                                    #endif
                            }
                            
                            Spacer()
                            
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(themeColor)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                        .background(isSelected ? themeColor.opacity(0.09) : (isHovered ? Color.primary.opacity(0.03) : Color.platformSystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isSelected ? themeColor : Color.primary.opacity(0.06), lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(color: isSelected ? themeColor.opacity(0.18) : .black.opacity(0.02), radius: 8, y: 3)
                        .scaleEffect(isSelected ? 1.015 : 1.0)
                    }
                    .buttonStyle(.plain)
                    #if os(iOS)
                    .sensoryFeedback(.selection, trigger: selectedIndex)
                    #endif
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredOption = hovering ? optIndex : nil
                        }
                    }
                }
            }
            
            // 3. Compact Pedagogical Accordions
            VStack(spacing: 8) {
                if let hint = question.hint, !hint.isEmpty {
                    collapsibleDiagnosticPill(
                        title: "Need a Hint?",
                        icon: "lightbulb.fill",
                        color: .yellow,
                        isExpanded: $isHintExpanded,
                        content: hint,
                        isProgressive: false
                    )
                }
                
                // Changed from `if case .practice = mode` to `if !mode.isTimed`
                if !mode.isTimed, let feedback = question.feedback, !feedback.isEmpty {
                    collapsibleDiagnosticPill(
                        title: "Step-by-Step Breakdown",
                        icon: "text.book.closed.fill",
                        color: themeColor,
                        isExpanded: $isFeedbackExpanded,
                        content: feedback,
                        isProgressive: true
                    )
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        #if os(macOS)
        .frame(maxWidth: 800)
        .frame(maxWidth: .infinity, alignment: .center)
        #endif
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isHintExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isFeedbackExpanded)
    }
    
    @ViewBuilder
    private func collapsibleDiagnosticPill(title: String, icon: String, color: Color, isExpanded: Binding<Bool>, content: String, isProgressive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.wrappedValue.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded.wrappedValue {
                Divider().padding(.horizontal, 16)
                Group {
                    if isProgressive {
                        ProgressiveStepsView(content: content, themeColor: themeColor)
                            .padding(14)
                    } else if content.contains("||") {
                        ExampleView(text: content, themeColor: themeColor)
                            .padding(14)
                    } else if content.contains("$") {
                        LatexView(latex: content.parsedMathToLatex, isTextMode: true)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(LocalizedStringKey(content.parsedInlineMathToMarkdown))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.platformSystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.02), radius: 6, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
    }
}

// MARK: - Progressive Feedback Engine
struct ProgressiveStepsView: View {
    let content: String
    let themeColor: Color
    @State private var revealedCount: Int = 1
    
    var steps: [String] {
        if content.contains("\n") {
            return content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        } else {
            let parts = content.components(separatedBy: ". ")
            return parts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map { $0.hasSuffix(".") ? $0 : $0 + "." }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<min(revealedCount, steps.count), id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(themeColor)
                        Text("STEP \(index + 1)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(themeColor)
                    }
                    
                    let stepText = steps[index]
                    if stepText.contains("$") {
                        LatexView(latex: stepText.parsedMathToLatex, isTextMode: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(LocalizedStringKey(stepText.parsedInlineMathToMarkdown))
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
                .background(themeColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            if revealedCount < steps.count {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        revealedCount += 1
                    }
                }) {
                    HStack {
                        Image(systemName: "eye.fill")
                        Text("Reveal Next Step")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(themeColor.gradient)
                    .clipShape(Capsule())
                    .shadow(color: themeColor.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }
}
