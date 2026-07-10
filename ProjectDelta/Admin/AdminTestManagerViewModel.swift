//
//  AdminTestManagerViewModel.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseFirestore
import Observation

// MARK: - ViewModel

@MainActor
@Observable
class AdminTestManagerViewModel {
    var subjectName: String = ""
    var lessonName: String = ""
    
    var customSubjectName: String = ""
    var customLessonName: String = ""
    
    var questionCount: Int = 10
    
    var generatedQuestions: [QuestionWrapper] = []
    
    var availableSubjects: [String] = []
    var availableLessons: [String] = []
    
    var isGenerating: Bool = false
    var isSaving: Bool = false
    var showEditor: Bool = false
    
    var existingTestId: String? = nil
    
    private let db = Firestore.firestore()
    
    init(subject: String, lesson: String, existingTestId: String? = nil) {
        self.subjectName = subject
        self.lessonName = lesson
        self.existingTestId = existingTestId
        
        if let testId = existingTestId, !testId.isEmpty {
            self.showEditor = true
            Task { await loadExistingTest(testId: testId, subjectName: subject) }
        }
    }
    
    private func loadExistingTest(testId: String, subjectName: String) async {
        isGenerating = true
        do {
            let subjectQuery = try await db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments()
            let subjectDocId = subjectQuery.documents.first?.documentID ?? subjectName
            
            let snapshot = try await db.collection("Subjects").document(subjectDocId)
                .collection("Tests").document(testId).collection("Questions").getDocuments()
            
            let rawQuestions = snapshot.documents.compactMap { try? $0.data(as: Question.self) }
            // Sort by ID to maintain a consistent editing sequence
            self.generatedQuestions = rawQuestions.sorted(by: { ($0.id ?? "") < ($1.id ?? "") }).map { QuestionWrapper(question: $0) }
        } catch {
            print("Failed to load existing test: \(error.localizedDescription)")
        }
        isGenerating = false
    }
    
    func fetchDropdownData() async {
        let subjectsSnap = try? await db.collection("Subjects").getDocuments()
        self.availableSubjects = (subjectsSnap?.documents.compactMap { $0.data()["name"] as? String } ?? []) + ["+ Add New Subject"]
        
        if !self.availableSubjects.contains(self.subjectName) {
            self.subjectName = self.availableSubjects.first ?? "+ Add New Subject"
        }
        
        await updateLessons(for: self.subjectName)
    }
    
    func updateLessons(for subjectName: String) async {
        guard !subjectName.isEmpty && subjectName != "+ Add New Subject" else {
            self.availableLessons = ["+ Add New Lesson"]
            self.lessonName = "+ Add New Lesson"
            return
        }
        
        do {
            let snapshot = try await db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments()
            
            guard let subjectDoc = snapshot.documents.first else {
                self.availableLessons = ["+ Add New Lesson"]
                self.lessonName = "+ Add New Lesson"
                return
            }
            let subjectId = subjectDoc.documentID
            let lessonsSnap = try await db.collection("Subjects").document(subjectId).collection("Lessons").getDocuments()
            
            self.availableLessons = lessonsSnap.documents.compactMap { $0.data()["name"] as? String } + ["+ Add New Lesson"]
            
            if !self.availableLessons.contains(self.lessonName) {
                self.lessonName = self.availableLessons.first ?? "+ Add New Lesson"
            }
        } catch {
            print("Error updating lessons: \(error.localizedDescription)")
            self.availableLessons = ["+ Add New Lesson"]
            self.lessonName = "+ Add New Lesson"
        }
    }
    
    var finalSubject: String {
        return subjectName == "+ Add New Subject" ? customSubjectName : subjectName
    }
    
    var finalLesson: String {
        return lessonName == "+ Add New Lesson" ? customLessonName : lessonName
    }
    
    func generateRecommendedTest() async {
        isGenerating = true
        try? await Task.sleep(for: .seconds(0.8))
        
        self.generatedQuestions = (0..<questionCount).map { _ in
            QuestionWrapper(question: Question(
                id: UUID().uuidString,
                correctOptionIndex: 0,
                options: ["", "", "", ""],
                points: 10,
                questionText: "",
                type: "multiple_choice",
                subject: finalSubject,
                subtopic: finalLesson,
                hint: "",
                feedback: "",
                testId: existingTestId
            ))
        }
        
        isGenerating = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showEditor = true }
    }
    
    func saveTestToDatabase() async {
        isSaving = true
        let targetSubject = finalSubject
        let targetLesson = finalLesson
        
        do {
            let subjectQuery = try await db.collection("Subjects").whereField("name", isEqualTo: targetSubject).getDocuments()
            let subjectId = subjectQuery.documents.first?.documentID ?? targetSubject
            
            let batch = db.batch()
            
            let testId = existingTestId ?? UUID().uuidString
            let testRef = db.collection("Subjects").document(subjectId).collection("Tests").document(testId)
            
            let testData: [String: Any] = [
                "questionAmount": generatedQuestions.count,
                "subject": targetSubject,
                "subtopic": targetLesson,
                "testIdentifier": Int.random(in: 1000...9999),
                "timeLimit": 60,
                "title": "\(targetLesson) Test",
                "createdAt": FieldValue.serverTimestamp() // Overwrites gracefully
            ]
            batch.setData(testData, forDocument: testRef, merge: true)
            
            // Clean up missing questions from deletion
            let existingQuestionsSnap = try await testRef.collection("Questions").getDocuments()
            let existingQIds = Set(existingQuestionsSnap.documents.map { $0.documentID })
            let currentQIds = Set(generatedQuestions.compactMap { $0.question.id })
            
            let idsToDelete = existingQIds.subtracting(currentQIds)
            for id in idsToDelete {
                batch.deleteDocument(testRef.collection("Questions").document(id))
                batch.deleteDocument(db.collection("questions").document(id))
            }
            
            // Commit all current questions
            for wrapper in generatedQuestions {
                var question = wrapper.question
                let qId = question.id ?? UUID().uuidString
                question.id = qId
                
                let docData: [String: Any] = [
                    "correctOptionIndex": question.correctOptionIndex,
                    "options": question.options,
                    "points": question.points,
                    "questionText": question.questionText,
                    "type": question.type,
                    "subject": targetSubject,
                    "subtopic": targetLesson,
                    "hint": question.hint ?? "",
                    "feedback": question.feedback ?? "",
                    "testId": testId
                ]
                
                let subRef = testRef.collection("Questions").document(qId)
                batch.setData(docData, forDocument: subRef)
                
                let flatRef = db.collection("questions").document(qId)
                batch.setData(docData, forDocument: flatRef)
            }
            
            try await batch.commit()
            withAnimation { showEditor = false }
        } catch {
            print("Failed to save test: \(error.localizedDescription)")
        }
        isSaving = false
    }
}

// MARK: - Main UI View

struct AdminTestManagerView: View {
    @State private var viewModel: AdminTestManagerViewModel
    @State private var expandedQuestionId: UUID? = nil
    @Environment(\.dismiss) var dismiss

    init(subjectName: String, lessonName: String, existingTestId: String? = nil) {
        _viewModel = State(wrappedValue: AdminTestManagerViewModel(subject: subjectName, lesson: lessonName, existingTestId: existingTestId))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if !viewModel.showEditor {
                        generatorConfigurationSection
                    } else {
                        editorSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
            .safeAreaPadding(.bottom, 120)
            .background(Color.platformSystemGroupedBackground.ignoresSafeArea())
            .navigationTitle(viewModel.existingTestId != nil ? "Edit Exam" : "Test Generator")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .scrollDismissesKeyboard(.interactively)
            .task { await viewModel.fetchDropdownData() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    @ViewBuilder
    private var generatorConfigurationSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 48))
                    .foregroundStyle(LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(.bottom, 8)
                
                Text("Generate a New Test")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Configure the subject and lesson parameters below to scaffold your assessment.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical)
            
            VStack(alignment: .leading, spacing: 16) {
                Label("Configuration", systemImage: "slider.horizontal.3")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Subject")
                            .fontWeight(.medium)
                        Spacer()
                        Picker("Subject", selection: $viewModel.subjectName) {
                            ForEach(viewModel.availableSubjects, id: \.self) { subject in
                                Text(subject).tag(subject)
                            }
                        }
                        .tint(.blue)
                    }
                    .onChange(of: viewModel.subjectName) { _, newSubject in
                        Task { await viewModel.updateLessons(for: newSubject) }
                    }
                    
                    if viewModel.subjectName == "+ Add New Subject" {
                        TextField("New Subject Name", text: $viewModel.customSubjectName)
                            .padding(10)
                            .background(Color.platformSystemBackground)
                            .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Lesson")
                            .fontWeight(.medium)
                        Spacer()
                        Picker("Lesson", selection: $viewModel.lessonName) {
                            ForEach(viewModel.availableLessons, id: \.self) { lesson in
                                Text(lesson).tag(lesson)
                            }
                        }
                        .tint(.blue)
                    }
                    
                    if viewModel.lessonName == "+ Add New Lesson" {
                        TextField("New Lesson Name", text: $viewModel.customLessonName)
                            .padding(10)
                            .background(Color.platformSystemBackground)
                            .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    Stepper(value: $viewModel.questionCount, in: 1...50) {
                        HStack {
                            Text("Question Count")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(viewModel.questionCount)")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }
                .padding()
                .background(Color.platformSecondarySystemGroupedBackground)
                .cornerRadius(12)
            }
            .padding()
            .background(Color.platformSystemBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            
            Button(action: {
                Task { await viewModel.generateRecommendedTest() }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: [.teal, .blue], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 56)
                        .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                    
                    if viewModel.isGenerating {
                        ProgressView().tint(.white)
                    } else {
                        HStack {
                            Text("Initialize Test Builder")
                                .font(.headline)
                                .fontWeight(.bold)
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .disabled(viewModel.isGenerating)
        }
    }
    
    @ViewBuilder
    private var editorSection: some View {
        VStack(spacing: 24) {
            // Context Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Test Editor")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(viewModel.finalSubject) - \(viewModel.finalLesson)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(viewModel.generatedQuestions.count) Qs")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.12, green: 0.65, blue: 0.65).opacity(0.15))
                    .foregroundColor(Color(red: 0.12, green: 0.65, blue: 0.65))
                    .cornerRadius(8)
            }
            
            // 2-Column Collapsible Grid Architecture
            VStack(spacing: 16) {
                let rowCount = (viewModel.generatedQuestions.count + 1) / 2
                
                ForEach(0..<rowCount, id: \.self) { rowIndex in
                    let index1 = rowIndex * 2
                    let index2 = index1 + 1
                    
                    // The Row of 2 Toggle Cards
                    HStack(spacing: 16) {
                        miniCard(for: index1)
                        if index2 < viewModel.generatedQuestions.count {
                            miniCard(for: index2)
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                    
                    // The Expanded Editor (Pushes content down perfectly)
                    if expandedQuestionId == viewModel.generatedQuestions[index1].id {
                        expandedEditor(for: index1)
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    } else if index2 < viewModel.generatedQuestions.count, expandedQuestionId == viewModel.generatedQuestions[index2].id {
                        expandedEditor(for: index2)
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    }
                }
            }
            
            // Add Question Footer Action
            Button(action: {
                withAnimation {
                    let newWrapper = QuestionWrapper(question: Question(
                        id: UUID().uuidString,
                        correctOptionIndex: 0,
                        options: ["", "", "", ""],
                        points: 10,
                        questionText: "",
                        type: "multiple_choice",
                        subject: viewModel.finalSubject,
                        subtopic: viewModel.finalLesson,
                        hint: "",
                        feedback: "",
                        testId: viewModel.existingTestId
                    ))
                    viewModel.generatedQuestions.append(newWrapper)
                    expandedQuestionId = newWrapper.id // Auto-expand new questions
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Another Question")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(14)
            }
            
            // Publish/Save Button
            Button(action: {
                Task {
                    await viewModel.saveTestToDatabase()
                    dismiss()
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: [.teal, Color(red: 0.18, green: 0.77, blue: 0.45)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 56)
                        .shadow(color: Color(red: 0.18, green: 0.77, blue: 0.45).opacity(0.3), radius: 10, y: 5)
                    
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Publish Edits")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .disabled(viewModel.isSaving || viewModel.generatedQuestions.isEmpty)
        }
    }
    
    // Custom Mini Card Component
    private func miniCard(for index: Int) -> some View {
        let wrapper = viewModel.generatedQuestions[index]
        let isExpanded = expandedQuestionId == wrapper.id
        let accent = Color(red: 0.12, green: 0.65, blue: 0.65)
        
        return Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if isExpanded {
                    expandedQuestionId = nil
                } else {
                    expandedQuestionId = wrapper.id
                }
            }
        }) {
            HStack {
                Text("Question \(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.title3)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isExpanded ? accent.opacity(0.15) : Color.platformSystemBackground)
            .foregroundColor(isExpanded ? accent : .primary)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(isExpanded ? 0 : 0.04), radius: 6, x: 0, y: 3)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isExpanded ? accent : Color.gray.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    // Custom Full-Width Editor Proxy
    private func expandedEditor(for index: Int) -> some View {
        let wrapper = viewModel.generatedQuestions[index]
        let safeBinding = Binding<Question>(
            get: {
                guard let safeIdx = viewModel.generatedQuestions.firstIndex(where: { $0.id == wrapper.id }) else { return wrapper.question }
                return viewModel.generatedQuestions[safeIdx].question
            },
            set: { newValue in
                guard let safeIdx = viewModel.generatedQuestions.firstIndex(where: { $0.id == wrapper.id }) else { return }
                viewModel.generatedQuestions[safeIdx].question = newValue
            }
        )
        
        return AdminManagerQuestionEditorCell(
            question: safeBinding,
            index: index,
            onDelete: {
                withAnimation {
                    viewModel.generatedQuestions.removeAll(where: { $0.id == wrapper.id })
                    if expandedQuestionId == wrapper.id { expandedQuestionId = nil }
                }
            }
        )
        .padding()
        .background(Color.platformSystemBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.12, green: 0.65, blue: 0.65).opacity(0.3), lineWidth: 2))
    }
}

// MARK: - Admin Question Editor Cell
struct AdminManagerQuestionEditorCell: View {
    @Binding var question: Question
    var index: Int
    var onDelete: () -> Void
    
    @State private var blocks: [QuestionBlockModel] = []
    let emeraldAccent = Color(red: 0.18, green: 0.77, blue: 0.45)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Editing Question \(index + 1)")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.12, green: 0.65, blue: 0.65))
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Question Blocks")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                UniversalBlockEditorView(blocks: $blocks)
                    .onChange(of: blocks) { _, newBlocks in
                        question.updateWith(blocks: newBlocks)
                    }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Multiple Choice Options")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .padding(.top, 8)
                
                ForEach(0..<4, id: \.self) { i in
                    HStack {
                        Button(action: { question.correctOptionIndex = i }) {
                            Image(systemName: question.correctOptionIndex == i ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(question.correctOptionIndex == i ? emeraldAccent : .gray)
                                .imageScale(.large)
                        }
                        .buttonStyle(.plain)
                        
                        TextField("Option \(i + 1)", text: Binding(
                            get: { question.options.indices.contains(i) ? question.options[i] : "" },
                            set: { if question.options.indices.contains(i) { question.options[i] = $0 } }
                        ))
                        .padding(10)
                        .background(Color.platformSecondarySystemBackground)
                        .cornerRadius(8)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Feedback & Hints (Optional)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .padding(.top, 8)
                
                TextField("Step-by-step Feedback", text: Binding(
                    get: { question.feedback ?? "" },
                    set: { question.feedback = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...5)
                .padding(10)
                .background(Color.platformSecondarySystemBackground)
                .cornerRadius(8)
                
                TextField("Quick Hint", text: Binding(
                    get: { question.hint ?? "" },
                    set: { question.hint = $0.isEmpty ? nil : $0 }
                ))
                .padding(10)
                .background(Color.platformSecondarySystemBackground)
                .cornerRadius(8)
            }
        }
        .onAppear {
            blocks = question.parsedBlocks
        }
    }
}
