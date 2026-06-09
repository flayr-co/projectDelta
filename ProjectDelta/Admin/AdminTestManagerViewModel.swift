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
    
    var existingTest: Test? = nil
    
    private let db = Firestore.firestore()
    
    init(subject: String, lesson: String, test: Test? = nil) {
        self.subjectName = subject
        self.lessonName = lesson
        self.existingTest = test
        
        if let test = test {
            self.showEditor = true
            Task { await loadExistingTest(test: test) }
        }
    }
    
    private func loadExistingTest(test: Test) async {
        isGenerating = true
        do {
            let subjectQuery = try await db.collection("Subjects").whereField("name", isEqualTo: test.subject).getDocuments()
            let subjectId = subjectQuery.documents.first?.documentID ?? test.subject
            
            let snapshot = try await db.collection("Subjects").document(subjectId)
                .collection("Tests").document(test.id!).collection("Questions").getDocuments()
            
            let rawQuestions = snapshot.documents.compactMap { try? $0.data(as: Question.self) }
            self.generatedQuestions = rawQuestions.map { QuestionWrapper(question: $0) }
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
            
            let testId = existingTest?.id ?? UUID().uuidString
            let testRef = db.collection("Subjects").document(subjectId).collection("Tests").document(testId)
            
            let testData: [String: Any] = [
                "questionAmount": generatedQuestions.count,
                "subject": targetSubject,
                "subtopic": targetLesson,
                "testIdentifier": existingTest?.testIdentifier ?? Int.random(in: 1000...9999),
                "timeLimit": 60,
                "title": existingTest?.title.isEmpty == false ? existingTest!.title : "\(targetLesson) Test",
                "createdAt": existingTest == nil ? FieldValue.serverTimestamp() : (existingTest!.createdAt ?? FieldValue.serverTimestamp())
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

    init(subjectName: String, lessonName: String, existingTest: Test? = nil) {
        _viewModel = State(wrappedValue: AdminTestManagerViewModel(subject: subjectName, lesson: lessonName, test: existingTest))
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
            .navigationTitle(viewModel.existingTest != nil ? "Edit Test" : "Generate Test")
            .navigationBarTitleDisplayMode(.inline)
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
