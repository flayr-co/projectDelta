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
    
    @State private var currentQuestionIndex = 0
    @State private var userAnswers: [Int?] = []
    @State private var userAnswer: Int?
    @State private var score: Int = 0
    @State private var practiceTestEnded: Bool = false
    @State private var navigateToCardView: Bool = false
    @State private var selectedQuestionIndex: Int = 0
    
    @State private var showUIControls: Bool = true
    
    var lessonID: String
    var practiceTestID: String

    var body: some View {
        // Redundant NavigationStack removed
        ZStack {
            (colorScheme == .dark ? Color.customDarkGray : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if showUIControls {
                    headerView
                        .transition(.opacity)
                }
                
                if !practiceTestEnded && practiceTestViewModel.questions.isEmpty {
                    Spacer()
                    ProgressView("Loading test...")
                    Spacer()
                } else if !practiceTestEnded && currentQuestionIndex < practiceTestViewModel.questions.count {
                    
                    if showUIControls {
                        questionSelectorView
                            .transition(.opacity)
                    }
                    
                    TabView(selection: $currentQuestionIndex) {
                        ForEach(0..<practiceTestViewModel.questions.count, id: \.self) { index in
                            questionContentPage(for: index)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                } else if practiceTestEnded {
                    testEndView
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !practiceTestEnded && !practiceTestViewModel.questions.isEmpty && showUIControls {
                testNavigationControls
                    .transition(.opacity)
            }
        }
        .task {
            await practiceTestViewModel.fetchPracticeTest(for: lessonID, practiceTestID: practiceTestID)
            userAnswers = [Int?](repeating: nil, count: practiceTestViewModel.questions.count)
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - COMPONENTS
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Button(action: {
                // Allows dismissing cleanly instead of hard-linking
                NotificationCenter.default.post(name: Notification.Name("dismissTest"), object: nil)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("Practice Test")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(colorScheme == .dark ? Color.customDarkGray : .white)
    }
    
    private var questionSelectorView: some View {
        HStack(spacing: 20) {
            Menu {
                Picker("Select Question", selection: $selectedQuestionIndex) {
                    ForEach(0..<practiceTestViewModel.questions.count, id: \.self) { index in
                        Text("Question \(index + 1)").tag(index)
                    }
                }
            } label: {
                Label("Question \(currentQuestionIndex + 1)", systemImage: "chevron.down")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? Color.cyan : Color.blue)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onChange(of: selectedQuestionIndex) { oldValue, newIndex in
                withAnimation {
                    currentQuestionIndex = newIndex
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
    
    private func questionContentPage(for index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(practiceTestViewModel.questions[index].parsedBlocks) { block in
                        if block.type == QuestionBlockType.text.rawValue {
                            Text(block.content)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if block.type == QuestionBlockType.math.rawValue {
                            LatexView(latex: "$$\n\(block.content.parsedMathToLatex)\n$$")
                                .frame(minHeight: calculateMathHeight(for: block.content))
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
                .padding(.horizontal)
                .padding(.top, 20)

                VStack(spacing: 16) {
                    ForEach(Array(practiceTestViewModel.questions[index].options.enumerated()), id: \.offset) { optionIndex, option in
                        Button(action: {
                            if index < userAnswers.count {
                                userAnswers[index] = optionIndex
                            }
                        }) {
                            optionView(option: option, isSelected: index < userAnswers.count ? userAnswers[index] == optionIndex : false)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 120)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showUIControls.toggle()
                }
            }
        }
        .scrollIndicators(.hidden)
    }
    
    private func calculateMathHeight(for latex: String) -> CGFloat {
        let lineBreaks = latex.components(separatedBy: "\\\\").count - 1
        let hasFraction = latex.contains("\\frac") || latex.contains("/")
        let baseHeight: CGFloat = 60
        return baseHeight + (CGFloat(lineBreaks) * 30) + (hasFraction ? 30 : 0)
    }

    private var testNavigationControls: some View {
        HStack {
            Button(action: {
                if currentQuestionIndex > 0 {
                    withAnimation { currentQuestionIndex -= 1 }
                }
            }) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(colorScheme == .dark ? .cyan : .blue)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(currentQuestionIndex == 0)
            .opacity(currentQuestionIndex == 0 ? 0.3 : 1)

            Spacer()
            
            Text("\(currentQuestionIndex + 1) of \(practiceTestViewModel.questions.count)")
                .font(.footnote.monospacedDigit())
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            Spacer()
            
            Button(action: {
                if currentQuestionIndex < practiceTestViewModel.questions.count - 1 {
                    withAnimation { currentQuestionIndex += 1 }
                } else {
                    if !practiceTestEnded {
                        postPracticeTestUpdate()
                    }
                }
            }) {
                Image(systemName: currentQuestionIndex < practiceTestViewModel.questions.count - 1 ? "chevron.right.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(currentQuestionIndex < userAnswers.count && userAnswers[currentQuestionIndex] == nil ? .gray : (colorScheme == .dark ? .cyan : .blue))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(currentQuestionIndex < userAnswers.count ? userAnswers[currentQuestionIndex] == nil : true)
        }
        .padding(.horizontal, 25)
        .padding(.bottom, 30)
    }
    
    private var testEndView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "flag.checkered.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(colorScheme == .dark ? .cyan : .blue)
            
            Text("Practice Test Complete!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Your score is \(score) out of \(practiceTestViewModel.questions.count)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                Button(action: {
                    withAnimation {
                        currentQuestionIndex = 0
                        score = 0
                        practiceTestEnded = false
                        userAnswers = [Int?](repeating: nil, count: practiceTestViewModel.questions.count)
                    }
                }) {
                    Text("Retry")
                        .fontWeight(.semibold)
                        .foregroundColor(colorScheme == .dark ? .cyan : .blue)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    NotificationCenter.default.post(name: Notification.Name("dismissTest"), object: nil)
                }) {
                    Text("Go Home")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(colorScheme == .dark ? Color.cyan : Color.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    func optionView(option: String, isSelected: Bool) -> some View {
        HStack {
            Text(option)
                .font(.body)
                .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white : .black))
                .padding()
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .padding(.trailing)
            }
        }
        .background(isSelected ? (colorScheme == .dark ? Color.cyan : Color.blue) : Color.gray.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? (colorScheme == .dark ? Color.cyan : Color.blue) : Color.clear, lineWidth: 2)
        )
    }

    private var currentQuestionDocId: String? {
        guard currentQuestionIndex < practiceTestViewModel.questions.count else { return nil }
        return practiceTestViewModel.questions[currentQuestionIndex].id
    }

    private func postPracticeTestUpdate() {
        practiceTestEnded = true

        score = 0
        for (index, answer) in userAnswers.enumerated() {
            if index < practiceTestViewModel.questions.count {
                if let answer = answer, answer == practiceTestViewModel.questions[index].correctOptionIndex {
                    score += 1
                }
            }
        }
        
        Task {
            guard let userId = viewModel.currentUser?.id, !userId.isEmpty else { return }
            
            let totalPointsChange = score * 10 - (practiceTestViewModel.questions.count - score) * 5
            
            await viewModel.updateUserPointsInFirestore(newPoints: (viewModel.currentUser?.points ?? 0) + totalPointsChange)
            await viewModel.storeTodaysPoints(pointsGainedToday: totalPointsChange)
            
            if let currentSubjectArea = practiceTestViewModel.currentSubject?.subjectArea {
                for (index, answer) in userAnswers.enumerated() {
                    if index < practiceTestViewModel.questions.count {
                        let questionDocId = practiceTestViewModel.questions[index].id ?? ""
                        let isCorrect = (answer == practiceTestViewModel.questions[index].correctOptionIndex)
                        
                        if !questionDocId.isEmpty {
                            do {
                                try await practiceTestViewModel.updateUserProgressForSubject(
                                    userID: userId,
                                    subjectArea: currentSubjectArea,
                                    answeredCorrectly: isCorrect,
                                    questionDocumentID: questionDocId
                                )
                            } catch {
                                print("Failed to update user progress for question \(questionDocId): \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
    }
}
