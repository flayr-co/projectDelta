//
//  NotebookDirectoryView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 9/17/26.
//


//
//  NotebookDirectoryView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseFirestore

struct NotebookDirectoryView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @State private var subjects: [String] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.platformSystemGroupedBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("My Notebook")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Review your saved scratchpad notes.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                            ForEach(subjects, id: \.self) { subject in
                                NavigationLink(destination: NotebookLessonListView(subjectName: subject)) {
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .font(.title2)
                                            .foregroundColor(.teal)
                                        Text(subject)
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary.opacity(0.5))
                                    }
                                    .padding(20)
                                    .background(Color.platformSystemBackground)
                                    .cornerRadius(16)
                                    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            do {
                let snapshot = try await Firestore.firestore().collection("Subjects").order(by: "orderIndex").getDocuments()
                await MainActor.run {
                    self.subjects = snapshot.documents.compactMap { $0.data()["name"] as? String }
                    self.isLoading = false
                }
            } catch {
                print("Failed to fetch subjects: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}

struct NotebookLessonListView: View {
    let subjectName: String
    @Environment(\.dismiss) var dismiss
    @State private var lessons: [Lesson] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.platformSystemGroupedBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 38, height: 38)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Text(subjectName)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if lessons.isEmpty {
                    Spacer()
                    ContentUnavailableView("No Notes Yet", systemImage: "pencil.and.scribble", description: Text("Take notes during a \(subjectName) test to see them here."))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(lessons) { lesson in
                                NavigationLink(destination: NotebookDetailView(subjectName: subjectName, lessonName: lesson.name)) {
                                    HStack {
                                        Image(systemName: "pencil.and.scribble")
                                            .font(.title3)
                                            .foregroundColor(.teal)
                                        
                                        Text(lesson.name)
                                            .font(.system(.headline, design: .rounded, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.bold))
                                            .foregroundColor(.secondary.opacity(0.5))
                                    }
                                    .padding(20)
                                    .background(Color.platformSystemBackground)
                                    .cornerRadius(16)
                                    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(24)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await fetchLessonsWithNotes()
        }
    }
    
    private func fetchLessonsWithNotes() async {
        let db = Firestore.firestore()
        do {
            let subjectQuery = try await db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments()
            if let subjectId = subjectQuery.documents.first?.documentID {
                let snapshot = try await db.collection("Subjects").document(subjectId).collection("Lessons").getDocuments()
                await MainActor.run {
                    self.lessons = snapshot.documents.compactMap { try? $0.data(as: Lesson.self) }.sorted { $0.lessonNumber < $1.lessonNumber }
                    self.isLoading = false
                }
            } else {
                await MainActor.run { self.isLoading = false }
            }
        } catch {
            print("Failed to load lessons: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }
}

struct NotebookDetailView: View {
    let subjectName: String
    let lessonName: String
    
    @Environment(AuthViewModel.self) var authVM
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @State private var notes: [QuestionNote] = []
    @State private var questions: [String: Question] = [:]
    @State private var isLoading = true
    
    var themeColor: Color { colorScheme == .dark ? .teal : .blue }
    
    var body: some View {
        ZStack {
            Color.platformSystemGroupedBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 38, height: 38)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("Notes")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                    Color.clear.frame(width: 38, height: 38)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if notes.isEmpty {
                    Spacer()
                    ContentUnavailableView("No Notes", systemImage: "doc.text.magnifyingglass", description: Text("You haven't saved any notes for \(lessonName) yet."))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 32) {
                            ForEach(notes) { note in
                                VStack(alignment: .leading, spacing: 0) {
                                    // Associated Question Render
                                    if let q = questions[note.id ?? ""] {
                                        VStack(alignment: .leading, spacing: 16) {
                                            Text("Original Problem")
                                                .font(.caption.weight(.bold))
                                                .foregroundColor(.secondary)
                                                .textCase(.uppercase)
                                            
                                            if !q.parsedBlocks.isEmpty {
                                                ForEach(q.parsedBlocks) { block in
                                                    if block.type == QuestionBlockType.math.rawValue {
                                                        LatexView(latex: "$$\n\(block.content.parsedMathToLatex)\n$$")
                                                    } else if block.type == QuestionBlockType.text.rawValue {
                                                        Text(LocalizedStringKey(block.content.parsedInlineMathToMarkdown))
                                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                                    }
                                                }
                                            } else {
                                                LatexView(latex: q.questionText.parsedMathToLatex, isTextMode: true)
                                            }
                                        }
                                        .padding(24)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.primary.opacity(0.03))
                                        
                                        Divider()
                                    }
                                    
                                    // User's Saved Scratchpad Note
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Image(systemName: "pencil.and.scribble")
                                                .foregroundColor(.teal)
                                            Text("Your Notes")
                                                .font(.caption.weight(.bold))
                                                .foregroundColor(.teal)
                                                .textCase(.uppercase)
                                            
                                            Spacer()
                                            
                                            Text(note.lastEdited, style: .date)
                                                .font(.caption2.weight(.medium))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        ReadOnlyScratchpad(jsonContent: note.content)
                                    }
                                    .padding(24)
                                    .background(Color.platformSystemBackground)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
                                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                            }
                        }
                        .padding(24)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await fetchNotesAndQuestions()
        }
    }
    
    private func fetchNotesAndQuestions() async {
        guard let userId = authVM.currentUser?.id else { return }
        
        do {
            let fetchedNotes = try await FirestoreManager.shared.fetchNotesForLesson(userId: userId, subject: subjectName, subtopic: lessonName)
            
            // Batch fetch the original questions so we can display the context
            let db = Firestore.firestore()
            var fetchedQs: [String: Question] = [:]
            
            for note in fetchedNotes {
                if let qId = note.id {
                    let doc = try? await db.collection("questions").document(qId).getDocument()
                    if let q = try? doc?.data(as: Question.self) {
                        fetchedQs[qId] = q
                    }
                }
            }
            
            await MainActor.run {
                self.notes = fetchedNotes
                self.questions = fetchedQs
                self.isLoading = false
            }
        } catch {
            print("Failed to load notes: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }
}

// Safely isolates the Observation model from the swiftui view update cycle
struct ReadOnlyScratchpad: View {
    @State private var vm = MathScratchpadViewModel()
    let jsonContent: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<vm.lines.count, id: \.self) { i in
                MathLineView(
                    viewModel: vm,
                    tokens: vm.lines[i],
                    isActive: false,
                    cursorIndex: nil,
                    lineIndex: i,
                    onCursorTap: { _ in }
                )
            }
        }
        .onAppear {
            vm.importStateFromJSON(jsonContent)
        }
    }
}
