//
//  AddTestView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseFirestore
import Observation

@MainActor
@Observable
class TestBuilderViewModel {
    var subjectName: String = ""
    var lessonName: String = ""
    var testTitle: String = ""
    
    var questionCount: Int = 10
    var generatedQuestions: [QuestionWrapper] = []
    
    var isGenerating: Bool = false
    var isSaving: Bool = false
    var showEditor: Bool = false
    var existingTestId: String? = nil
    
    private let db = Firestore.firestore()
    
    func initialize(subject: String, initialLesson: String, testId: String?) async {
        self.subjectName = subject
        self.lessonName = initialLesson
        self.existingTestId = testId
        
        if let tId = testId {
            await loadExistingTest(testId: tId)
        }
    }
    
    private func loadExistingTest(testId: String) async {
        isGenerating = true
        do {
            let subjectQuery = try await db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments()
            let subjectId = subjectQuery.documents.first?.documentID ?? subjectName
            
            let snapshot = try await db.collection("Subjects").document(subjectId).collection("Tests").document(testId).collection("Questions").getDocuments()
            let rawQuestions = snapshot.documents.compactMap { try? $0.data(as: Question.self) }
            self.generatedQuestions = rawQuestions.map { QuestionWrapper(question: $0) }
            self.showEditor = true
        } catch {
            print("Failed to load test questions: \(error.localizedDescription)")
        }
        isGenerating = false
    }
    
    func generateRecommendedTest() async {
        guard !lessonName.isEmpty else { return }
        isGenerating = true
        
        try? await Task.sleep(for: .seconds(1.5)) // Simulated generation delay
        
        self.generatedQuestions = (0..<questionCount).map { _ in
            QuestionWrapper(question: Question(
                id: UUID().uuidString,
                correctOptionIndex: 0,
                options: ["", "", "", ""],
                points: 10,
                questionText: "",
                type: "multiple_choice",
                subject: subjectName,
                subtopic: lessonName,
                hint: "",
                feedback: "",
                testId: ""
            ))
        }
        
        withAnimation {
            showEditor = true
        }
        isGenerating = false
    }
    
    func saveTestToDatabase() async {
        isSaving = true
        
        do {
            let subjectQuery = try await db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments()
            let subjectId = subjectQuery.documents.first?.documentID ?? subjectName
            
            let batch = db.batch()
            
            let testId = existingTestId ?? UUID().uuidString
            let testRef = db.collection("Subjects").document(subjectId).collection("Tests").document(testId)
            
            let testData: [String: Any] = [
                "questionAmount": generatedQuestions.count,
                "subject": subjectName,
                "subtopic": lessonName,
                "testIdentifier": Int.random(in: 1000...9999),
                "timeLimit": 60,
                "title": testTitle.isEmpty ? "\(lessonName) Assessment" : testTitle,
                "createdAt": FieldValue.serverTimestamp()
            ]
            batch.setData(testData, forDocument: testRef)
            
            for wrapper in generatedQuestions {
                let question = wrapper.question
                let qId = question.id ?? UUID().uuidString
                
                let docData: [String: Any] = [
                    "correctOptionIndex": question.correctOptionIndex,
                    "options": question.options,
                    "points": question.points,
                    "questionText": question.questionText,
                    "type": question.type,
                    "subject": subjectName,
                    "subtopic": lessonName,
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
        } catch {
            print("Failed to save test: \(error.localizedDescription)")
        }
        
        isSaving = false
    }
}

struct AddTestView: View {
    let subjectName: String
    var existingTest: Test? = nil
    var availableLessons: [Lesson] = [] // Passed in to allow selection
    
    @State private var viewModel = TestBuilderViewModel()
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let emeraldAccent = Color(red: 0.18, green: 0.70, blue: 0.45)
    
    var themeBackground: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.11, blue: 0.10) : Color(red: 0.97, green: 0.96, blue: 0.94)
    }
    var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0.18, green: 0.17, blue: 0.16) : Color.white
    }

    var body: some View {
        Group {
            if viewModel.showEditor {
                editorContent
            } else {
                generatorContent
            }
        }
        .navigationTitle(existingTest != nil ? "Edit Assessment" : "Test Generator")
        .navigationBarTitleDisplayMode(.inline)
        .background(themeBackground.ignoresSafeArea())
        .task {
            // Set initial lesson if available
            let initialLesson = existingTest?.subtopic ?? availableLessons.first?.name ?? ""
            await viewModel.initialize(subject: subjectName, initialLesson: initialLesson, testId: existingTest?.id)
            if existingTest != nil {
                viewModel.testTitle = existingTest?.title ?? existingTest?.subject ?? "Untitled Test"
            }
        }
    }
    
    @ViewBuilder
    private var generatorContent: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 50))
                        .foregroundColor(emeraldAccent)
                        .padding(.bottom, 10)
                    
                    Text("Build an Assessment")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Select a lesson from your curriculum and define how many questions to generate.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .padding(.top, 40)
                
                // Form Fields
                VStack(spacing: 24) {
                    // Lesson Selection UI
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target Lesson")
                            .font(.headline)
                        
                        Menu {
                            if availableLessons.isEmpty {
                                Button("No Lessons Available", action: {})
                                    .disabled(true)
                            } else {
                                ForEach(availableLessons) { lesson in
                                    Button(lesson.name) {
                                        viewModel.lessonName = lesson.name
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(viewModel.lessonName.isEmpty ? "Select a Lesson..." : viewModel.lessonName)
                                    .foregroundColor(viewModel.lessonName.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(cardBackground)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
                        }
                    }
                    
                    // Question Count Slider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Question Count")
                            .font(.headline)
                        
                        HStack {
                            Slider(value: Binding(
                                get: { Double(viewModel.questionCount) },
                                set: { viewModel.questionCount = Int($0) }
                            ), in: 1...50, step: 1)
                            .tint(emeraldAccent)
                            
                            Text("\(viewModel.questionCount)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .frame(width: 40)
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
                    }
                    
                    // Generate Button
                    Button(action: {
                        Task { await viewModel.generateRecommendedTest() }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(viewModel.lessonName.isEmpty ? Color.gray.opacity(0.3) : emeraldAccent)
                                .frame(height: 56)
                            
                            if viewModel.isGenerating {
                                ProgressView().tint(.white)
                            } else {
                                Text("Generate Questions")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(viewModel.lessonName.isEmpty ? .secondary : .white)
                            }
                        }
                    }
                    .disabled(viewModel.isGenerating || viewModel.lessonName.isEmpty)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var editorContent: some View {
        VStack(spacing: 0) {
            List {
                Section(header: Text("Assessment Settings")) {
                    TextField("Test Title", text: $viewModel.testTitle)
                        .font(.headline)
                }
                
                Section {
                    Text("Review the generated questions below. You can edit the text, math formulas, or multiple-choice options.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                
                ForEach(viewModel.generatedQuestions) { wrapper in
                    let safeBinding = Binding<Question>(
                        get: {
                            guard let index = viewModel.generatedQuestions.firstIndex(where: { $0.id == wrapper.id }) else { return wrapper.question }
                            return viewModel.generatedQuestions[index].question
                        },
                        set: { newValue in
                            guard let index = viewModel.generatedQuestions.firstIndex(where: { $0.id == wrapper.id }) else { return }
                            viewModel.generatedQuestions[index].question = newValue
                        }
                    )
                    
                    let displayIndex = viewModel.generatedQuestions.firstIndex(where: { $0.id == wrapper.id }) ?? 0
                    
                    AdminQuestionEditorCell(
                        question: safeBinding,
                        index: displayIndex,
                        onDelete: {
                            withAnimation {
                                viewModel.generatedQuestions.removeAll(where: { $0.id == wrapper.id })
                            }
                        }
                    )
                }
                
                Button(action: {
                    withAnimation {
                        viewModel.generatedQuestions.append(QuestionWrapper(question: Question(
                            id: UUID().uuidString,
                            correctOptionIndex: 0,
                            options: ["", "", "", ""],
                            points: 10,
                            questionText: "",
                            type: "multiple_choice",
                            subject: viewModel.subjectName,
                            subtopic: viewModel.lessonName,
                            hint: "",
                            feedback: "",
                            testId: viewModel.existingTestId
                        )))
                    }
                }) {
                    HStack {
                        Spacer()
                        Label("Add Blank Question", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(emeraldAccent)
                        Spacer()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            
            // Fixed bottom save bar
            VStack {
                Divider()
                Button(action: {
                    Task {
                        await viewModel.saveTestToDatabase()
                        dismiss()
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(emeraldAccent)
                            .frame(height: 56)
                        
                        if viewModel.isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Publish Assessment")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(viewModel.isSaving)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .background(cardBackground.ignoresSafeArea(edges: .bottom))
        }
    }
}

// MARK: - Admin Question Editor Cell
struct AdminQuestionEditorCell: View {
    @Binding var question: Question
    var index: Int
    var onDelete: () -> Void
    
    @State private var blocks: [QuestionBlockModel] = []
    let emeraldAccent = Color(red: 0.18, green: 0.70, blue: 0.45)
    
    var body: some View {
        Section(header: HStack {
            Text("Question \(index + 1)")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }) {
            VStack(alignment: .leading, spacing: 16) {
                UniversalBlockEditorView(blocks: $blocks)
                    .onChange(of: blocks) { _, newBlocks in
                        question.updateWith(blocks: newBlocks)
                    }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Answer Choices")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(0..<4, id: \.self) { i in
                        HStack(spacing: 12) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    question.correctOptionIndex = i
                                }
                            }) {
                                Image(systemName: question.correctOptionIndex == i ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(question.correctOptionIndex == i ? emeraldAccent : .gray.opacity(0.5))
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                            
                            TextField("Option \(i + 1)", text: Binding(
                                get: { question.options.indices.contains(i) ? question.options[i] : "" },
                                set: { if question.options.indices.contains(i) { question.options[i] = $0 } }
                            ))
                            .padding(10)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Optional Hint")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Provide a hint to help students...", text: Binding(
                        get: { question.hint ?? "" },
                        set: { question.hint = $0.isEmpty ? nil : $0 }
                    ))
                    .padding(10)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            blocks = question.parsedBlocks
        }
    }
}
