//
//  UniversalTestView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseFirestore
import Combine
import Foundation

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
    
    // Scratchpad State Integration
    @State private var isScratchpadVisible: Bool = false
    @State private var scratchpadViewModel = MathScratchpadViewModel()
    
    @State private var timeRemaining: Int = 300
    
    @AppStorage("hideCustomTabBar") private var hideCustomTabBar: Bool = false
    @State private var isTestActive: Bool = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var mode: TestMode
    
    var themeColor: Color {
        colorScheme == .dark ? Color(red: 0.20, green: 0.88, blue: 0.78) : Color(red: 0.05, green: 0.65, blue: 0.85)
    }

    var body: some View {
        Group {
#if os(macOS)
            macOSLayout
#else
            iOSLayout
#endif
        }
        .background(
            ZStack {
                if colorScheme == .dark {
                    Color.black.ignoresSafeArea()
                    RadialGradient(
                        colors: [themeColor.opacity(0.08), Color.clear],
                        center: .top,
                        startRadius: 20,
                        endRadius: 600
                    )
                    .ignoresSafeArea()
                } else {
                    Color(red: 0.96, green: 0.97, blue: 0.99).ignoresSafeArea()
                }
            }
        )
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
        .sheet(isPresented: $isScratchpadVisible) {
            MathScratchpadView(viewModel: scratchpadViewModel)
                .presentationDetents([.fraction(0.55), .fraction(0.85), .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.85)))
                .presentationCornerRadius(36)
                .presentationBackground(.ultraThinMaterial)
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
        .onChange(of: currentQuestionIndex) { _, _ in
            scratchpadViewModel.clearAll()
        }
    }
    
    // MARK: - Core Logic & Data Extraction
    
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
    
    private func extractMath(from question: Question) -> String {
        if !question.parsedBlocks.isEmpty {
            for block in question.parsedBlocks {
                if block.type == QuestionBlockType.math.rawValue {
                    return block.content
                }
            }
            for block in question.parsedBlocks {
                if block.type == QuestionBlockType.text.rawValue, block.content.contains("$") {
                    let parts = block.content.split(separator: "$")
                    if parts.count > 1 { return String(parts[1]) }
                }
            }
        }
        return question.questionText.replacingOccurrences(of: "$", with: "")
    }

    // MARK: - macOS Layout
    #if os(macOS)
    private var macOSLayout: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .top) {
                Color.clear.ignoresSafeArea()
                
                if mode.isTimed && !buttonTapped {
                    macOSIntroView
                        .frame(maxHeight: .infinity)
                } else if testViewModel.isGeneratingQuiz {
                    VStack(spacing: 24) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(themeColor)
                        Text("Loading assessment pool...")
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
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
            .frame(maxWidth: .infinity)
            
            if isScratchpadVisible && !testViewModel.isGeneratingQuiz && !testViewModel.isQuizComplete && !testViewModel.questions.isEmpty && (!mode.isTimed || buttonTapped) {
                Divider().ignoresSafeArea()
                MathScratchpadView(viewModel: scratchpadViewModel)
                    .frame(width: 460)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .background(.ultraThinMaterial)
            }
        }
    }
    
    private var macOSHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(Color.primary.opacity(0.06), in: .circle)
                        .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()
                
                HStack(spacing: 12) {
                    Text(mode.subtopicName ?? mode.subjectName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    if mode.isTimed {
                        Divider().frame(height: 14)
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                            Text(timeString).monospacedDigit()
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(timeRemaining <= 60 ? .red : themeColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((timeRemaining <= 60 ? Color.red : themeColor).opacity(0.12), in: .capsule)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {
                        if scratchpadViewModel.isEmpty {
                            if currentQuestionIndex < testViewModel.questions.count {
                                let activeQuestion = testViewModel.questions[currentQuestionIndex]
                                scratchpadViewModel.loadEquation(extractMath(from: activeQuestion))
                            }
                        }
                        withAnimation(.snappy) { isScratchpadVisible.toggle() }
                    }) {
                        Image(systemName: "pencil.and.scribble")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isScratchpadVisible ? .white : themeColor)
                            .frame(width: 36, height: 36)
                            .background(isScratchpadVisible ? themeColor : themeColor.opacity(0.12), in: .circle)
                            .overlay(Circle().stroke(isScratchpadVisible ? Color.clear : themeColor.opacity(0.3), lineWidth: 1))
                            .shadow(color: isScratchpadVisible ? themeColor.opacity(0.4) : .clear, radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Interactive Scratchpad")

                    if let role = authViewModel.currentUser?.role, (role == .teacher || role == .parent) {
                        Button(action: { showAdminEditor = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                                .background(Color.primary.opacity(0.06), in: .circle)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(LinearGradient(colors: [themeColor.opacity(0.8), themeColor], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(currentQuestionIndex + 1) / CGFloat(max(testViewModel.questions.count, 1)))
                        .shadow(color: themeColor.opacity(0.5), radius: 6, y: 0)
                        .animation(.snappy, value: currentQuestionIndex)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 32)
        }
    }
    
    private var macOSBottomNavigationBar: some View {
        HStack(spacing: 12) {
            Button(action: { withAnimation(.snappy) { currentQuestionIndex -= 1 } }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(currentQuestionIndex == 0 ? Color.secondary.opacity(0.3) : Color.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.06), in: .circle)
                    .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(currentQuestionIndex == 0)

            Spacer()
            
            Text("Question \(currentQuestionIndex + 1) of \(testViewModel.questions.count)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .padding(.horizontal, 24)
                .frame(height: 44)
                .background(.ultraThinMaterial, in: .capsule)
                .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))

            Spacer()

            if currentQuestionIndex < testViewModel.questions.count - 1 {
                Button(action: { withAnimation(.snappy) { currentQuestionIndex += 1 } }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(themeColor.gradient, in: .circle)
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
                    HStack(spacing: 6) {
                        Text(isSubmitting ? "Submitting..." : "Turn In")
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    .background(themeColor.gradient, in: .capsule)
                    .shadow(color: themeColor.opacity(0.35), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
        .frame(maxWidth: 700)
    }
    
    private var macOSIntroView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(themeColor.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .overlay(Circle().stroke(themeColor.opacity(0.3), lineWidth: 1))
                Image(systemName: "timer")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(themeColor)
            }
            
            VStack(spacing: 8) {
                Text(mode.subtopicName ?? "General \(mode.subjectName)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text("Timed Assessment")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                Text("5 Minute Session • Instant Diagnostic Breakdown")
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Button {
                withAnimation(.snappy) {
                    buttonTapped = true
                    timeRemaining = 300
                }
                testViewModel.fetchTest(mode: mode)
            } label: {
                Text("Begin Exam")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeColor)
            .clipShape(.capsule)
            .shadow(color: themeColor.opacity(0.35), radius: 15, y: 8)
            .padding(.top, 16)
        }
    }
    #endif

    // MARK: - iOS Layout
    #if os(iOS)
    private var iOSLayout: some View {
        VStack(spacing: 0) {
            iOSHeader
                .zIndex(2)
                
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
                        .foregroundStyle(.secondary)
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
                    
                    // Scrim gradient behind navigation bar for zero collision
                    LinearGradient(
                        colors: [
                            Color.clear,
                            (colorScheme == .dark ? Color.black : Color(red: 0.96, green: 0.97, blue: 0.99)).opacity(0.85),
                            (colorScheme == .dark ? Color.black : Color(red: 0.96, green: 0.97, blue: 0.99))
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    .allowsHitTesting(false)
                    
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
                        .foregroundStyle(.primary)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: .circle)
                        .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()
                
                Text(mode.subtopicName ?? mode.subjectName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        if scratchpadViewModel.isEmpty {
                            if currentQuestionIndex < testViewModel.questions.count {
                                let activeQuestion = testViewModel.questions[currentQuestionIndex]
                                scratchpadViewModel.loadEquation(extractMath(from: activeQuestion))
                            }
                        }
                        withAnimation(.snappy) { isScratchpadVisible.toggle() }
                    }) {
                        Image(systemName: "pencil.and.scribble")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(isScratchpadVisible ? .white : themeColor)
                            .frame(width: 38, height: 38)
                            .background(isScratchpadVisible ? themeColor : themeColor.opacity(0.12), in: .circle)
                            .overlay(Circle().stroke(isScratchpadVisible ? Color.clear : themeColor.opacity(0.3), lineWidth: 1))
                            .shadow(color: isScratchpadVisible ? themeColor.opacity(0.4) : .clear, radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)

                    if let role = authViewModel.currentUser?.role, (role == .teacher || role == .parent) {
                        Button(action: { showAdminEditor = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 38, height: 38)
                                .background(.ultraThinMaterial, in: .circle)
                                .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)
            
            // Luminous glowing progress indicator
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                    Capsule()
                        .fill(LinearGradient(colors: [themeColor.opacity(0.7), themeColor], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(currentQuestionIndex + 1) / CGFloat(max(testViewModel.questions.count, 1)))
                        .shadow(color: themeColor.opacity(0.6), radius: 4, y: 0)
                        .animation(.snappy, value: currentQuestionIndex)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06)),
            alignment: .bottom
        )
    }
    
    private var introView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(themeColor.opacity(0.12))
                        .frame(width: 120, height: 120)
                        .overlay(Circle().stroke(themeColor.opacity(0.25), lineWidth: 1.5))
                        .shadow(color: themeColor.opacity(0.2), radius: 20, y: 10)
                    Image(systemName: "timer")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(themeColor)
                }
                
                Text(mode.subtopicName ?? "General \(mode.subjectName)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Text("Timed Assessment")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text("5 minutes to complete all questions.")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
            
            Button(action: {
                withAnimation(.snappy) {
                    buttonTapped = true
                    timeRemaining = 300
                }
                testViewModel.fetchTest(mode: mode)
            }) {
                Text("Begin Exam")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(themeColor.gradient, in: .rect(cornerRadius: 22, style: .continuous))
                    .shadow(color: themeColor.opacity(0.4), radius: 16, y: 8)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    private var bottomNavigationBar: some View {
        HStack(spacing: 16) {
            Button(action: {
                if currentQuestionIndex > 0 {
                    withAnimation(.snappy) { currentQuestionIndex -= 1 }
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(currentQuestionIndex == 0 ? Color.secondary.opacity(0.25) : Color.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(0.06), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(currentQuestionIndex == 0)
            
            Spacer(minLength: 0)
            
            Text("Question \(currentQuestionIndex + 1) of \(testViewModel.questions.count)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(minWidth: 140)
            
            Spacer(minLength: 0)
            
            let isLastQuestion = currentQuestionIndex == testViewModel.questions.count - 1
            if !isLastQuestion {
                Button(action: {
                    withAnimation(.snappy) { currentQuestionIndex += 1 }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(themeColor.gradient, in: .circle)
                        .shadow(color: themeColor.opacity(0.4), radius: 8, y: 3)
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
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(themeColor.gradient, in: .circle)
                        .shadow(color: themeColor.opacity(0.4), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: colorScheme == .dark
                                    ? [Color.white.opacity(0.2), Color.white.opacity(0.04)]
                                    : [Color.black.opacity(0.08), Color.black.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 20, y: 10)
        )
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
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
                    
                    let strokeGradient = AngularGradient(
                        colors: [ringColor.opacity(0.6), ringColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    )
                    
                    // Top Radial Dashboard
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .stroke(Color.primary.opacity(0.05), lineWidth: 18)
                                .frame(width: 180, height: 180)
                            
                            Circle()
                                .trim(from: 0.0, to: CGFloat(percentage))
                                .stroke(strokeGradient, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 180, height: 180)
                                .shadow(color: ringColor.opacity(0.4), radius: 12, y: 4)
                                .animation(.spring(response: 1.2, dampingFraction: 0.75).delay(0.2), value: percentage)
                            
                            VStack(spacing: 0) {
                                Text("\(percentageInt)%")
                                    .font(.system(size: 42, weight: .black, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text(getLetterGrade(for: percentageInt))
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundStyle(ringColor)
                            }
                        }
                        .padding(.top, 24)
                        
                        VStack(spacing: 6) {
                            Text("Assessment Complete")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("Comprehensive performance overview and solutions.")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
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
                    VStack(spacing: 20) {
                        ForEach(Array(snapshot.questionResults.enumerated()), id: \.element.id) { index, result in
                            VStack(alignment: .leading, spacing: 0) {
                                // Question Card Header
                                HStack {
                                    Text("Question \(index + 1)")
                                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                                        .foregroundStyle(result.isCorrect ? .green : .red)
                                        .textCase(.uppercase)
                                    Spacer()
                                    HStack(spacing: 5) {
                                        Image(systemName: result.isCorrect ? "checkmark" : "xmark")
                                            .font(.system(size: 11, weight: .black))
                                        Text(result.isCorrect ? "Correct" : "Incorrect")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                    }
                                    .foregroundStyle(result.isCorrect ? .green : .red)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background((result.isCorrect ? Color.green : Color.red).opacity(0.12), in: .capsule)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(Color.primary.opacity(0.03))
                                
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
                                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                                            .foregroundStyle(.primary)
                                                            .fixedSize(horizontal: false, vertical: true)
                                                    }
                                                } else if block.type == QuestionBlockType.math.rawValue {
                                                    LatexView(latex: "$$\n\(block.content.parsedMathToLatex)\n$$")
                                                        .frame(maxWidth: .infinity, alignment: .center)
                                                        .padding(.vertical, 16)
                                                        .padding(.horizontal, 16)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                                .fill(colorScheme == .dark ? Color(white: 0.08) : Color(white: 0.96))
                                                                .overlay(
                                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                                                )
                                                        )
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
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                                .foregroundStyle(.primary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    
                                    // User Choice vs Correct Solution
                                    VStack(spacing: 8) {
                                        let userChoice = (result.userSelectedOptionIndex != nil && result.userSelectedOptionIndex! >= 0 && result.userSelectedOptionIndex! < result.options.count) ? result.options[result.userSelectedOptionIndex!] : "No Answer Submitted"
                                        
                                        answerMetricRow(
                                            label: "Your Answer",
                                            text: userChoice,
                                            isCorrect: result.isCorrect,
                                            isUserChoice: true
                                        )
                                        
                                        if !result.isCorrect && result.correctOptionIndex >= 0 && result.correctOptionIndex < result.options.count {
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
                                                    .foregroundStyle(themeColor)
                                                Text("Step-by-Step Breakdown")
                                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                                    .foregroundStyle(.primary)
                                                    .textCase(.uppercase)
                                            }
                                            
                                            ProgressiveStepsView(content: result.feedback, themeColor: themeColor)
                                        }
                                        .padding(20)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.primary.opacity(0.03), in: .rect(cornerRadius: 18, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 1))
                                        .padding(.top, 8)
                                    }
                                }
                                .padding(20)
                            }
                            .background(colorScheme == .dark ? Color(white: 0.12) : Color.white)
                            .clipShape(.rect(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: colorScheme == .dark ? [Color.white.opacity(0.12), Color.white.opacity(0.03)] : [Color.black.opacity(0.06), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 14, y: 6)
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
                        .foregroundStyle(.white)
                        .frame(maxWidth: 300)
                        .frame(height: 52)
                        .background(themeColor.gradient, in: .capsule)
                        .shadow(color: themeColor.opacity(0.35), radius: 12, y: 5)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                }
            }
            .padding(.bottom, 60)
#if os(macOS)
            .frame(maxWidth: .infinity, alignment: .center)
            .safeAreaPadding(.top, 40)
#endif
        }
    }
    
    // MARK: - Helper Views
    @ViewBuilder
    private func kpiPill(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
            }
            .foregroundStyle(.secondary)
            
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(colorScheme == .dark ? Color(white: 0.12) : Color.white, in: .rect(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.03), radius: 8, y: 4)
    }
    
    @ViewBuilder
    private func answerMetricRow(label: String, text: String, isCorrect: Bool, isUserChoice: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label + ":")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            
            if text.contains("$") {
                LatexView(latex: text.parsedMathToLatex, isTextMode: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(LocalizedStringKey(text.parsedInlineMathToMarkdown))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(isUserChoice ? (isCorrect ? .green : .red) : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            isUserChoice
                ? (isCorrect ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                : Color.primary.opacity(0.04),
            in: .rect(cornerRadius: 12, style: .continuous)
        )
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
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            if index < testViewModel.questions.count {
                IsolatedQuestionCard(
                    question: testViewModel.questions[index],
                    index: index,
                    themeColor: themeColor,
                    mode: mode
                )
                .padding(.top, 20)
            }
        }
        #if os(macOS)
        .safeAreaPadding(.bottom, 60)
        #else
        // Generous padding ensures hints and options never collide with the floating bottom bar
        .safeAreaPadding(.bottom, 140)
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
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isHintExpanded: Bool = false
    @State private var isFeedbackExpanded: Bool = false
    @State private var hoveredOption: Int? = nil
    @State private var blockInteractionStates: [String: Bool] = [:]
    
    let optionLetters = ["A", "B", "C", "D", "E", "F"]
    
    // OLED obsidian surface with subtle ambient depth
    var cardSurfaceColor: Color {
        colorScheme == .dark ? Color(red: 0.10, green: 0.11, blue: 0.13) : Color.white
    }
    
    var cardBorderGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.white.opacity(0.16), Color.white.opacity(0.03)]
                : [Color.black.opacity(0.08), Color.black.opacity(0.02)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        let qId = question.id ?? UUID().uuidString
        let selectedIndex = testViewModel.userAnswers[qId]
        
        #if os(macOS)
        let mainSpacing: CGFloat = 28
        let canvasPadding: CGFloat = 36
        let optionSpacing: CGFloat = 14
        let questionFontSize: CGFloat = 24
        #else
        let mainSpacing: CGFloat = 20
        let canvasPadding: CGFloat = 26
        let optionSpacing: CGFloat = 12
        let questionFontSize: CGFloat = 21
        #endif
        
        VStack(alignment: .leading, spacing: mainSpacing) {
            
            // 1. Primary Problem Canvas
            if !question.parsedBlocks.isEmpty {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(question.parsedBlocks) { block in
                        if block.type == QuestionBlockType.text.rawValue {
                            if block.content.contains("$") {
                                LatexView(latex: block.content.parsedMathToLatex, isTextMode: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(LocalizedStringKey(block.content.parsedInlineMathToMarkdown))
                                    .font(.system(size: questionFontSize, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else if block.type == QuestionBlockType.math.rawValue {
                            LatexView(latex: "$$\n\(block.content.parsedMathToLatex)\n$$")
                                .padding(.horizontal, 24)
                                .padding(.vertical, 22)
                                .frame(maxWidth: .infinity, alignment: .center)
                                // High-contrast, glowing recessed viewport
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(colorScheme == .dark ? Color(red: 0.05, green: 0.06, blue: 0.07) : Color(white: 0.96))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: colorScheme == .dark
                                                            ? [themeColor.opacity(0.3), Color.white.opacity(0.05)]
                                                            : [Color.black.opacity(0.08), Color.clear],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.5) : Color.clear, radius: 8, y: 4)
                                )
                            
                            if let caption = block.caption, !caption.isEmpty {
                                Text(LocalizedStringKey(caption.parsedInlineMathToMarkdown))
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.top, 6)
                            }
                        } else if block.type == QuestionBlockType.graph.rawValue {
                            let isInteractive = blockInteractionStates[block.id] ?? false
                            
                            ZStack(alignment: .topTrailing) {
                                InlineGraphRenderer(graphString: block.content, themeColor: themeColor)
                                    .padding(.vertical, 10)
                                    .allowsHitTesting(isInteractive)
                                
#if os(iOS)
                                Button {
                                    withAnimation(.snappy) { blockInteractionStates[block.id] = !isInteractive }
                                } label: {
                                    Image(systemName: isInteractive ? "lock.open.fill" : "lock.fill")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(isInteractive ? Color.white : themeColor)
                                        .padding(10)
                                        .background(isInteractive ? themeColor : Color.primary.opacity(0.08), in: .circle)
                                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                                }
                                .padding(12)
#endif
                            }
                        }
                    }
                }
                .padding(canvasPadding)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(cardSurfaceColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(cardBorderGradient, lineWidth: 1.2)
                        )
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.04), radius: 20, y: 8)
                )
            }
            
            // 2. Multiple Choice Options
            VStack(spacing: optionSpacing) {
                ForEach(0..<question.options.count, id: \.self) { optIndex in
                    let optionText = question.options[optIndex]
                    let isSelected = selectedIndex == optIndex
                    let isHovered = hoveredOption == optIndex
                    let letter = optIndex < optionLetters.count ? optionLetters[optIndex] : "\(optIndex + 1)"
                    
                    Button(action: {
                        withAnimation(.snappy) {
                            testViewModel.selectAnswer(for: qId, optionIndex: optIndex)
                        }
                    }) {
                        HStack(spacing: 16) {
                            // High-contrast Letter Badge
                            Text(letter)
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(isSelected ? Color.black : Color.primary)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(isSelected ? themeColor : Color.primary.opacity(0.08))
                                        .overlay(
                                            Circle()
                                                .stroke(isSelected ? Color.white.opacity(0.4) : Color.primary.opacity(0.1), lineWidth: 1)
                                        )
                                        .shadow(color: isSelected ? themeColor.opacity(0.6) : Color.clear, radius: 8, y: 0)
                                )
                            
                            if optionText.contains("$") {
                                LatexView(latex: optionText.parsedMathToLatex, isTextMode: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(LocalizedStringKey(optionText.parsedInlineMathToMarkdown))
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(isSelected ? (colorScheme == .dark ? Color.white : themeColor) : Color.primary)
                                    #if os(macOS)
                                    .font(.system(.title3, design: .rounded, weight: isSelected ? .heavy : .semibold))
                                    #else
                                    .font(.system(size: 17, weight: isSelected ? .bold : .medium, design: .rounded))
                                    #endif
                            }
                            
                            Spacer()
                            
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(themeColor)
                                    .shadow(color: themeColor.opacity(0.5), radius: 6, y: 0)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    isSelected
                                        ? (colorScheme == .dark ? themeColor.opacity(0.18) : themeColor.opacity(0.10))
                                        : (isHovered ? Color.primary.opacity(0.05) : cardSurfaceColor)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(
                                            isSelected
                                                ? themeColor
                                                : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)),
                                            lineWidth: isSelected ? 2 : 1
                                        )
                                )
                                .shadow(
                                    color: isSelected ? themeColor.opacity(0.25) : .black.opacity(colorScheme == .dark ? 0.25 : 0.03),
                                    radius: isSelected ? 12 : 6,
                                    y: isSelected ? 4 : 2
                                )
                        )
                        .scaleEffect(isSelected ? 1.01 : 1.0)
                    }
                    .buttonStyle(KeypadPressStyle())
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
            
            // 3. Compact Accordions
            VStack(spacing: 14) {
                if let hint = question.hint, !hint.isEmpty {
                    collapsibleDiagnosticPill(
                        title: "Need a Hint?",
                        icon: "lightbulb.fill",
                        color: Color(red: 1.0, green: 0.75, blue: 0.0),
                        isExpanded: $isHintExpanded,
                        content: hint,
                        isProgressive: false
                    )
                }
                
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
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        #if os(macOS)
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity, alignment: .center)
        #endif
    }
    
    @ViewBuilder
    private func collapsibleDiagnosticPill(title: String, icon: String, color: Color, isExpanded: Binding<Bool>, content: String, isProgressive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.snappy) {
                    isExpanded.wrappedValue.toggle()
                }
            }) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(color)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded.wrappedValue {
                Divider()
                    .padding(.horizontal, 20)
                    .opacity(0.6)
                Group {
                    if isProgressive {
                        ProgressiveStepsView(content: content, themeColor: themeColor)
                            .padding(20)
                    } else if content.contains("||") {
                        ExampleView(text: content, themeColor: themeColor)
                            .padding(20)
                    } else if content.contains("$") {
                        LatexView(latex: content.parsedMathToLatex, isTextMode: true)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(LocalizedStringKey(content.parsedInlineMathToMarkdown))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardSurfaceColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(cardBorderGradient, lineWidth: 1)
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.03), radius: 10, y: 4)
        )
    }
}

// MARK: - Progressive Feedback Engine
struct ProgressiveStepsView: View {
    let content: String
    let themeColor: Color
    @State private var revealedCount: Int = 1
    @Environment(\.colorScheme) var colorScheme
    
    var steps: [String] {
        if content.contains("\n") {
            let lines = content.components(separatedBy: "\n")
            return lines.compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty ? nil : trimmed
            }
        } else {
            let parts = content.components(separatedBy: ". ")
            return parts.compactMap { part in
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { return nil }
                return trimmed.hasSuffix(".") ? trimmed : trimmed + "."
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(0..<min(revealedCount, steps.count), id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(themeColor)
                        Text("STEP \(index + 1)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(themeColor)
                    }
                    
                    let stepText = steps[index]
                    if stepText.contains("$") {
                        LatexView(latex: stepText.parsedMathToLatex, isTextMode: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(LocalizedStringKey(stepText.parsedInlineMathToMarkdown))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(themeColor.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(themeColor.opacity(0.25), lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            if revealedCount < steps.count {
                Button(action: {
                    withAnimation(.snappy) {
                        revealedCount += 1
                    }
                }) {
                    HStack {
                        Image(systemName: "eye.fill")
                        Text("Reveal Next Step")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(themeColor.gradient, in: .capsule)
                    .shadow(color: themeColor.opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(KeypadPressStyle())
                .padding(.top, 6)
            }
        }
    }
}
