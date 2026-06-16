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
    
    var lessonID: String
    var practiceTestID: String
    var subjectName: String

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
            await practiceTestViewModel.fetchPracticeTest(for: lessonID, practiceTestID: practiceTestID, subjectName: subjectName)
        }
        .navigationTitle("Practice Test")
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
            
            if !practiceTestEnded && practiceTestViewModel.questions.isEmpty {
                ProgressView("Loading test...")
            } else if !practiceTestEnded {
                VStack(spacing: 0) {
                    macOSProgressBar
                    
                    ScrollView(showsIndicators: false) {
                        questionContentPage(for: currentQuestionIndex)
                            .padding(.top, 40)
                            .padding(.bottom, 100)
                    }
                    
                    macOSBottomNavigationBar
                }
            } else {
                testEndView
            }
        }
    }
    
    private var macOSProgressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<practiceTestViewModel.questions.count, id: \.self) { index in
                Capsule()
                    .fill(index == currentQuestionIndex ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(height: 6)
            }
        }
        .padding(24)
        .background(Color.platformSystemBackground)
    }

    private var macOSBottomNavigationBar: some View {
        HStack {
            Button("Previous") {
                withAnimation { currentQuestionIndex -= 1 }
            }
            .disabled(currentQuestionIndex == 0)
            .controlSize(.large)
            
            Spacer()
            
            Text("Question \(currentQuestionIndex + 1) of \(practiceTestViewModel.questions.count)")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundColor(.secondary)
            
            Spacer()
            
            if currentQuestionIndex < practiceTestViewModel.questions.count - 1 {
                Button("Next") {
                    withAnimation { currentQuestionIndex += 1 }
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            } else {
                Button("Turn In") {
                    postPracticeTestUpdate()
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(24)
        .background(Color.platformSystemBackground)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.primary.opacity(0.1)), alignment: .top)
    }
    #endif

    // MARK: - MOBILE LAYOUT (iOS)
    #if os(iOS)
    private var iOSLayout: some View {
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
    #endif
    
    // MARK: - SHARED COMPONENTS
    
    @ViewBuilder
    private func questionContentPage(for index: Int) -> some View {
        ScrollView {
            let question = practiceTestViewModel.questions[index]
            
            // Guard clause to prevent ghost questions
            if !question.parsedBlocks.isEmpty {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Content Card
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(question.parsedBlocks) { block in
                            if block.type == QuestionBlockType.text.rawValue {
                                Text(block.content)
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            } else if block.type == QuestionBlockType.math.rawValue {
                                LatexView(latex: "$$\n\(block.content.parsedMathToLatex)\n$$")
                                    .padding(16)
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

                    // Options
                    VStack(spacing: 16) {
                        let currentOptions = question.options
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
                #if os(macOS)
                .frame(maxWidth: 800, alignment: .center)
                .frame(maxWidth: .infinity)
                #endif
            }
        }
    }
    
    func optionView(option: String, isSelected: Bool) -> some View {
        HStack {
            Text(option)
                .font(.system(.body, design: .rounded))
                .foregroundColor(isSelected ? .white : .primary)
                .padding()
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .padding(.trailing)
            }
        }
        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private var testEndView: some View {
        VStack(spacing: 24) {
            Image(systemName: "flag.checkered.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("Practice Test Complete!")
                .font(.system(.title, design: .rounded, weight: .bold))
            
            Text("Score: \(score) / \(practiceTestViewModel.questions.count)")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                Button("Go Home") { dismiss() }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
            }
        }
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
        }
    }
}
