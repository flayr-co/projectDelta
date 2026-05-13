//
//  QuickTestView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/17/23.
//

// QuickTestView
import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct QuickTestView: View {
    // MARK: - PROPERTIES
    @Environment(AuthViewModel.self) var viewModel
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State private var currentQuestionIndex = 0
    @State private var userAnswers = [Int?](repeating: nil, count: 10)
    @State private var userAnswer: Int?
    @State private var score: Int = 0
    @State private var quizEnded: Bool = false
    @State private var navigateToCardView: Bool = false
    @State private var selectedQuestionIndex: Int = 0
    
    @State private var showUIControls: Bool = true
    var subject: String
    
    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color.customDarkGray : Color.white)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if showUIControls {
                        headerView
                            .transition(.opacity)
                    }
                    
                    if !quizEnded && quizViewModel.questions.isEmpty {
                        Spacer()
                        ProgressView("Loading test...")
                        Spacer()
                    } else if !quizEnded && currentQuestionIndex < quizViewModel.questions.count {
                        
                        // Question Selector
                        if showUIControls {
                            questionSelectorView
                                .transition(.opacity)
                        }
                        
                        TabView(selection: $currentQuestionIndex) {
                            ForEach(0..<quizViewModel.questions.count, id: \.self) { index in
                                questionContentPage(for: index)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        
                    } else if quizEnded {
                        quizEndView
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !quizEnded && !quizViewModel.questions.isEmpty && showUIControls {
                    testNavigationControls
                        .transition(.opacity)
                }
            }
            .task {
                // Fetch random test first
                quizViewModel.fetchRandomTest(for: subject)
                
                // Then, handle user progress.
                guard let userId = viewModel.userSession?.uid else {
                    print("User ID is nil or empty")
                    return
                }

                do {
                    // FIXED: Changed quizViewModel to viewModel (AuthViewModel) to correctly access the fetch function
                    let userProgress = try await viewModel.fetchUserProgress(forUserID: userId)
                    if let userProgress = userProgress {
                        quizViewModel.userProgress = userProgress
                    } else {
                        try await viewModel.createUserProgress(userId: userId)
                    }
                } catch {
                    print("Error fetching user progress: \(error.localizedDescription)")
                }
            }
            .onChange(of: quizViewModel.questions.count) { oldValue, newCount in
                if newCount > 0 && userAnswers.count != newCount {
                    userAnswers = [Int?](repeating: nil, count: newCount)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    // MARK: - COMPONENTS
    
    private var headerView: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: CardView().toolbar(.hidden, for: .navigationBar)) {
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

            Text(subject)
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
                    ForEach(0..<quizViewModel.questions.count, id: \.self) { index in
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
                Text(quizViewModel.questions[index].questionText)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 16) {
                    ForEach(Array(quizViewModel.questions[index].options.enumerated()), id: \.offset) { optionIndex, option in
                        Button(action: {
                            userAnswers[index] = optionIndex
                        }) {
                            optionView(option: option, isSelected: userAnswers[index] == optionIndex)
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
            
            Text("\(currentQuestionIndex + 1) of \(quizViewModel.questions.count)")
                .font(.footnote.monospacedDigit())
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            Spacer()
            
            Button(action: {
                if currentQuestionIndex < quizViewModel.questions.count - 1 {
                    withAnimation { currentQuestionIndex += 1 }
                } else {
                    if !quizEnded {
                        quizViewModel.setCurrentQuestionDocId(for: currentQuestionIndex)
                        postQuizUpdate()
                    }
                }
            }) {
                Image(systemName: currentQuestionIndex < quizViewModel.questions.count - 1 ? "chevron.right.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(userAnswers[currentQuestionIndex] == nil ? .gray : (colorScheme == .dark ? .cyan : .blue))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(userAnswers[currentQuestionIndex] == nil)
        }
        .padding(.horizontal, 25)
        .padding(.bottom, 30)
    }
    
    private var quizEndView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "flag.checkered.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(colorScheme == .dark ? .cyan : .blue)
            
            Text("Test Complete!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Your score is \(score) out of \(quizViewModel.questions.count)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                Button(action: {
                    withAnimation {
                        currentQuestionIndex = 0
                        score = 0
                        quizEnded = false
                        userAnswers = [Int?](repeating: nil, count: quizViewModel.questions.count)
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
                
                NavigationLink(destination: CardView().toolbar(.hidden, for: .navigationBar)) {
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
    
    private func postQuizUpdate() {
        quizEnded = true
        print("Quiz has ended. Points and progress will now be updated....\n")

        score = 0
        for (index, answer) in userAnswers.enumerated() {
            if let answer = answer, answer == quizViewModel.questions[index].correctOptionIndex {
                score += 1
            }
        }
        
        Task {
            guard let userId = viewModel.currentUser?.id, !userId.isEmpty else { return }
            
            let totalPointsChange = score * 10 - (quizViewModel.questions.count - score) * 5
            
            await viewModel.updateUserPointsInFirestore(newPoints: (viewModel.currentUser?.points ?? 0) + totalPointsChange)
            await viewModel.storeTodaysPoints(pointsGainedToday: totalPointsChange)
            
            if let currentSubjectArea = quizViewModel.currentSubject?.subjectArea {
                if let subjectAreaEnum = SubjectArea(rawValue: currentSubjectArea),
                   let currentQuestionDocId = quizViewModel.currentQuestionDocId {
                    do {
                        try await quizViewModel.updateUserProgressForSubject(
                            userID: userId,
                            subjectArea: subjectAreaEnum,
                            answeredCorrectly: score == quizViewModel.questions.count,
                            questionDocumentID: currentQuestionDocId
                        )
                    } catch {
                        print("Failed to update user progress in Firestore: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
} //: QUICKTESTVIEW

#Preview {
    QuickTestView(subject: "Pre-Algebra")
        .environment(AuthViewModel())
        .environment(QuizViewModel(authViewModel: AuthViewModel()))
}
