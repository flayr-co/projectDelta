//
//  AdminTestManagerViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/27/26.
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
    
    private let db = Firestore.firestore()
    
    init(subject: String, lesson: String) {
        self.subjectName = subject
        self.lessonName = lesson
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
            let snapshot = try await db.collection("Subjects")
                .whereField("name", isEqualTo: subjectName)
                .getDocuments()
            
            guard let subjectDoc = snapshot.documents.first else {
                self.availableLessons = ["+ Add New Lesson"]
                self.lessonName = "+ Add New Lesson"
                return
            }
            let subjectId = subjectDoc.documentID
            
            let lessonsSnap = try await db.collection("Subjects")
                .document(subjectId).collection("Lessons").getDocuments()
            
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
        try? await Task.sleep(for: .seconds(1.5))
        
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
                testId: ""
            ))
        }
        
        isGenerating = false
        showEditor = true
    }
    
    func saveTestToDatabase() async {
        isSaving = true
        let targetSubject = finalSubject
        let targetLesson = finalLesson
        
        do {
            let subjectQuery = try await db.collection("Subjects").whereField("name", isEqualTo: targetSubject).getDocuments()
            let subjectId = subjectQuery.documents.first?.documentID ?? targetSubject
            
            let batch = db.batch()
            
            let testId = UUID().uuidString
            let testRef = db.collection("Subjects").document(subjectId).collection("Tests").document(testId)
            
            // FIXED: Included required Codable fields (questionAmount, testIdentifier, timeLimit) to prevent silent decoding failures.
            // FIXED: Removed "id" field to prevent @DocumentID Firestore collisions.
            let testData: [String: Any] = [
                "questionAmount": generatedQuestions.count,
                "subject": targetSubject,
                "subtopic": targetLesson,
                "testIdentifier": Int.random(in: 1000...9999),
                "timeLimit": 60,
                "title": "\(targetLesson) Test",
                "createdAt": FieldValue.serverTimestamp()
            ]
            batch.setData(testData, forDocument: testRef)
            
            for wrapper in generatedQuestions {
                let question = wrapper.question
                let qId = question.id ?? UUID().uuidString
                
                // FIXED: Removed "id" injection
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
            generatedQuestions.removeAll()
            showEditor = false
        } catch {
            print("Failed to save test: \(error.localizedDescription)")
        }
        isSaving = false
    }
}

// MARK: - Main View

struct AdminTestManagerView: View {
    @State private var viewModel: AdminTestManagerViewModel
    @Environment(\.dismiss) var dismiss

    init(subjectName: String, lessonName: String) {
        _viewModel = State(wrappedValue: AdminTestManagerViewModel(subject: subjectName, lesson: lessonName))
    }

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.showEditor {
                    generatorConfigurationSection
                } else {
                    editorSection
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .task { await viewModel.fetchDropdownData() }
        }
    }
    
    @ViewBuilder
    private var generatorConfigurationSection: some View {
        Section("Selection") {
            Picker("Subject", selection: $viewModel.subjectName) {
                ForEach(viewModel.availableSubjects, id: \.self) { subject in
                    Text(subject).tag(subject)
                }
            }
            .onChange(of: viewModel.subjectName) { _, newSubject in
                Task { await viewModel.updateLessons(for: newSubject) }
            }
            
            if viewModel.subjectName == "+ Add New Subject" {
                TextField("New Subject Name", text: $viewModel.customSubjectName)
            }
            
            Picker("Lesson", selection: $viewModel.lessonName) {
                ForEach(viewModel.availableLessons, id: \.self) { lesson in
                    Text(lesson).tag(lesson)
                }
            }
            
            if viewModel.lessonName == "+ Add New Lesson" {
                TextField("New Lesson Name", text: $viewModel.customLessonName)
            }
            
            Stepper(value: $viewModel.questionCount, in: 1...50) {
                Text("Number of Questions: \(viewModel.questionCount)")
            }
        }
        
        Button("Generate Questions") {
            Task { await viewModel.generateRecommendedTest() }
        }
        .disabled(
            (viewModel.subjectName == "+ Add New Subject" && viewModel.customSubjectName.isEmpty) ||
            (viewModel.lessonName == "+ Add New Lesson" && viewModel.customLessonName.isEmpty) ||
            viewModel.isGenerating
        )
    }
    
    @ViewBuilder
    private var editorSection: some View {
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
                    subject: viewModel.finalSubject,
                    subtopic: viewModel.finalLesson,
                    hint: "",
                    feedback: "",
                    testId: ""
                )))
            }
        }) {
            Label("Add Another Question", systemImage: "plus.circle.fill")
                .font(.headline)
                .foregroundColor(.blue)
        }
        
        Button(action: {
            Task {
                await viewModel.saveTestToDatabase()
                dismiss()
            }
        }) {
            HStack {
                Spacer()
                if viewModel.isSaving {
                    ProgressView().tint(.green)
                } else {
                    Text("Save Test to Database")
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                Spacer()
            }
        }
        .disabled(viewModel.isSaving)
    }
}

// MARK: - Reusable Editor Subcomponents

struct AdminQuestionEditorCell: View {
    @Binding var question: Question
    let index: Int
    let onDelete: () -> Void
    
    @State private var blocks: [QuestionBlockModel] = []
    
    var body: some View {
        Section {
            HStack {
                Text("Problem \(index + 1)")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            .padding(.bottom, 4)
            
            ForEach($blocks) { $block in
                AdminBlockEditorRow(block: $block) {
                    withAnimation {
                        blocks.removeAll { $0.id == block.id }
                    }
                }
            }
            
            HStack {
                Button(action: { addBlock(type: .text) }) {
                    Label("Text", systemImage: "text.alignleft")
                        .font(.caption).fontWeight(.bold)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                
                Button(action: { addBlock(type: .math) }) {
                    Label("Equation", systemImage: "function")
                        .font(.caption).fontWeight(.bold)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                
                Button(action: { addBlock(type: .graph) }) {
                    Label("Graph", systemImage: "chart.xyaxis.line")
                        .font(.caption).fontWeight(.bold)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
            .padding(.vertical, 6)
            
            ForEach(0..<question.options.count, id: \.self) { optIndex in
                HStack {
                    Button(action: { question.correctOptionIndex = optIndex }) {
                        Image(systemName: question.correctOptionIndex == optIndex ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(question.correctOptionIndex == optIndex ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    TextField("Option \(optIndex + 1)", text: Binding(
                        get: { question.options[optIndex] },
                        set: { question.options[optIndex] = $0 }
                    ))
                }
            }
            
            TextField("Hint (Optional)", text: Binding(
                get: { question.hint ?? "" },
                set: { question.hint = $0 }
            ))
            .font(.footnote)
            .foregroundColor(.secondary)
            
        }
        .onAppear {
            var initialBlocks = question.parsedBlocks
            if initialBlocks.isEmpty {
                initialBlocks.append(QuestionBlockModel(type: QuestionBlockType.text.rawValue, content: ""))
            }
            blocks = initialBlocks
        }
        .onChange(of: blocks) { _, newValue in
            question.updateWith(blocks: newValue)
        }
    }
    
    private func addBlock(type: QuestionBlockType) {
        withAnimation {
            let newBlock = QuestionBlockModel(
                type: type.rawValue,
                content: "",
                graphType: type == .graph ? QuestionGraphType.equation.rawValue : nil
            )
            blocks.append(newBlock)
        }
    }
}

struct AdminBlockEditorRow: View {
    @Binding var block: QuestionBlockModel
    var onRemove: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(block.type.uppercased())
                    .font(.caption2)
                    .fontWeight(.black)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            
            if block.type == QuestionBlockType.graph.rawValue {
                Picker("Graph Type", selection: Binding(
                    get: { block.graphType ?? QuestionGraphType.equation.rawValue },
                    set: { block.graphType = $0 }
                )) {
                    ForEach(QuestionGraphType.allCases, id: \.rawValue) { type in
                        Text(type.rawValue).tag(type.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            if block.type == QuestionBlockType.text.rawValue {
                TextField("Enter text...", text: $block.content, axis: .vertical)
                    .lineLimit(2...8)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else if block.type == QuestionBlockType.math.rawValue {
                TextField("Enter LaTeX...", text: $block.content, axis: .vertical)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            } else {
                TextField(block.graphType == QuestionGraphType.equation.rawValue ? "Enter function (e.g. y = 2x)" : "Enter points data", text: $block.content, axis: .vertical)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
        .padding(.vertical, 4)
    }
}
