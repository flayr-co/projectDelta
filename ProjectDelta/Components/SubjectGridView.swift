//
//  SubjectGridView.swift
//  ProjectDelta
//

import SwiftUI
import Firebase

enum NavigationSource {
    case homeView
    case cardView
    case testView
}

struct SubjectGridView: View {
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(LessonViewModel.self) var lessonVM

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    var navigationSource: NavigationSource
    
    let warmTan = Color(red: 0.97, green: 0.96, blue: 0.94)
    let emeraldAccent = Color(red: 0.18, green: 0.80, blue: 0.44)
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? Color(red: 0.10, green: 0.10, blue: 0.12) : warmTan)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Bar
                    HStack {
                        BackButtonView {
                            dismiss()
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Dashboard Title Block
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Curriculum")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(1.5)
                        
                        Text("Choose a Subject")
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    
                    // Grid Content Scroll
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(quizViewModel.subjects, id: \.self) { subject in
                                NavigationLink {
                                    switch navigationSource {
                                    case .homeView:
                                        LessonView(subjectName: subject)
                                            .environment(lessonVM)
                                    case .testView:
                                        LessonSelectionView(subjectName: subject)
                                            .environment(quizViewModel)
                                    case .cardView:
                                        QuickTestView(subject: subject)
                                            .environment(quizViewModel)
                                    }
                                } label: {
                                    subjectCard(for: subject)
                                }
                                .buttonStyle(SubjectCardButtonStyle())
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
        }
        .task {
            do {
                quizViewModel.subjects = try await quizViewModel.fetchSubjectsFromFirestore()
            } catch {
                print("Error fetching subjects in SubjectGridView: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Card Component View Builder
    
    @ViewBuilder
    private func subjectCard(for subject: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: iconForSubject(subject))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(emeraldAccent)
                    .frame(width: 44, height: 44)
                    .background(emeraldAccent.opacity(colorScheme == .dark ? 0.15 : 0.1))
                    .cornerRadius(12)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            
            Text(subject)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(height: 135)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.16, green: 0.16, blue: 0.19) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.04), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Helpers
    
    private func iconForSubject(_ subject: String) -> String {
        let lower = subject.lowercased()
        if lower.contains("algebra") { return "function" }
        if lower.contains("calculus") { return "chart.xyaxis.line" }
        if lower.contains("geometry") { return "triangle" }
        if lower.contains("physics") || lower.contains("aero") { return "rocket.tilt.fill" }
        if lower.contains("linear") || lower.contains("matrix") { return "line.3.horizontal.circle" }
        return "book.closed.fill"
    }
}

// MARK: - Lesson Selection View (For Practice Mode)

struct LessonSelectionView: View {
    var subjectName: String
    @Environment(QuizViewModel.self) var quizViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @State private var lessons: [String] = []
    @State private var isLoading = true
    
    let warmTan = Color(red: 0.97, green: 0.96, blue: 0.94)
    let emeraldAccent = Color(red: 0.18, green: 0.80, blue: 0.44)
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(red: 0.10, green: 0.10, blue: 0.12) : warmTan)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    BackButtonView { dismiss() }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(subjectName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.5)
                    
                    Text("Select a Lesson")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                if isLoading {
                    Spacer()
                    ProgressView("Finding practice material...")
                        .tint(emeraldAccent)
                    Spacer()
                } else if lessons.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Practice Available",
                        systemImage: "book.closed.fill",
                        description: Text("There are currently no generated tests available for this subject.")
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(lessons, id: \.self) { lessonName in
                                NavigationLink(destination: QuickTestView(subject: subjectName, subtopic: lessonName).environment(quizViewModel)) {
                                    lessonCard(for: lessonName)
                                }
                                .buttonStyle(SubjectCardButtonStyle())
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await fetchLessonsWithTests()
        }
    }
    
    private func fetchLessonsWithTests() async {
        isLoading = true
        do {
            let db = Firestore.firestore()
            
            // Fetch hierarchical tests
            let testsSnap = try await db.collection("Tests").whereField("subject", isEqualTo: subjectName).getDocuments()
            let testLessons = testsSnap.documents.compactMap { $0.data()["lesson"] as? String }
            
            // Fetch flat questions
            let flatSnap = try await db.collection("questions").whereField("subject", isEqualTo: subjectName).getDocuments()
            let flatLessons = flatSnap.documents.compactMap { $0.data()["subtopic"] as? String }
            
            let combined = Array(Set(testLessons + flatLessons)).filter { !$0.isEmpty }.sorted()
            self.lessons = combined
        } catch {
            print("Error parsing practice lessons: \(error)")
        }
        isLoading = false
    }
    
    @ViewBuilder
    private func lessonCard(for lessonName: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(emeraldAccent)
                .frame(width: 44, height: 44)
                .background(emeraldAccent.opacity(colorScheme == .dark ? 0.15 : 0.1))
                .cornerRadius(12)
            
            Text(lessonName)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary.opacity(0.4))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.16, green: 0.16, blue: 0.19) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Button Style Extensions

struct SubjectCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    SubjectGridView(navigationSource: .homeView)
        .environment(QuizViewModel(authViewModel: AuthViewModel()))
        .environment(LessonViewModel())
}
