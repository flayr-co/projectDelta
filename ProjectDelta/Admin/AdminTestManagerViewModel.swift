//
//  AdminTestManagerViewModel.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/27/26.
//

import SwiftUI
import FirebaseFirestore

@MainActor
@Observable
class AdminTestManagerViewModel {
    var subjectName: String = ""
    var lessonName: String = ""
    
    // Separate state variables so the TextField doesn't break the Picker binding
    var customSubjectName: String = ""
    var customLessonName: String = ""
    
    var generatedQuestions: [Question] = []
    
    // Dropdown Data
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
        
        // Safety check to prevent SwiftUI Picker invalid tag error
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
            
            // Critical Fix: Force the lesson name to a valid tag so the Picker doesn't visually break
            if !self.availableLessons.contains(self.lessonName) {
                self.lessonName = self.availableLessons.first ?? "+ Add New Lesson"
            }
            
        } catch {
            print("Error updating lessons: \(error.localizedDescription)")
            self.availableLessons = ["+ Add New Lesson"]
            self.lessonName = "+ Add New Lesson"
        }
    }
    
    // Computed properties to evaluate what actually gets saved to the database
    var finalSubject: String {
        return subjectName == "+ Add New Subject" ? customSubjectName : subjectName
    }
    
    var finalLesson: String {
        return lessonName == "+ Add New Lesson" ? customLessonName : lessonName
    }
    
    func generateRecommendedTest() async {
        isGenerating = true
        try? await Task.sleep(for: .seconds(1.5))
        
        self.generatedQuestions = (1...10).map { i in
            Question(
                id: UUID().uuidString,
                correctOptionIndex: 0,
                options: ["", "", "", ""],
                points: 10,
                questionText: "Question \(i)",
                type: "multipleChoice",
                subject: finalSubject,
                subtopic: finalLesson,
                hint: "",
                feedback: "",
                testId: ""
            )
        }
        
        isGenerating = false
        showEditor = true
    }
    
    func saveTestToDatabase() async {
        isSaving = true
        let targetSubject = finalSubject
        let targetLesson = finalLesson
        
        do {
            let batch = db.batch()
            
            let testId = UUID().uuidString
            let testRef = db.collection("Tests").document(testId)
            let testData: [String: Any] = [
                "id": testId,
                "subject": targetSubject,
                "lesson": targetLesson,
                "title": "\(targetLesson) Test",
                "createdAt": FieldValue.serverTimestamp()
            ]
            batch.setData(testData, forDocument: testRef)
            
            for question in generatedQuestions {
                let docData: [String: Any] = [
                    "id": question.id ?? UUID().uuidString,
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
                
                let subRef = testRef.collection("Questions").document(question.id ?? UUID().uuidString)
                batch.setData(docData, forDocument: subRef)
                
                let flatRef = db.collection("questions").document(question.id ?? UUID().uuidString)
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

// MARK: - View

struct AdminTestManagerView: View {
    @State private var viewModel: AdminTestManagerViewModel
    @Environment(\.dismiss) var dismiss

    init(subjectName: String, lessonName: String) {
        _viewModel = State(initialValue: AdminTestManagerViewModel(subject: subjectName, lesson: lessonName))
    }

    var body: some View {
        NavigationStack {
            List {
                if !viewModel.showEditor {
                    Section("Selection") {
                        Picker("Subject", selection: $viewModel.subjectName) {
                            ForEach(viewModel.availableSubjects, id: \.self) { Text($0) }
                        }
                        .onChange(of: viewModel.subjectName) { _, newSubject in
                            Task { await viewModel.updateLessons(for: newSubject) }
                        }
                        
                        if viewModel.subjectName == "+ Add New Subject" {
                            TextField("New Subject Name", text: $viewModel.customSubjectName)
                        }
                        
                        Picker("Lesson", selection: $viewModel.lessonName) {
                            ForEach(viewModel.availableLessons, id: \.self) { Text($0) }
                        }
                        
                        if viewModel.lessonName == "+ Add New Lesson" {
                            TextField("New Lesson Name", text: $viewModel.customLessonName)
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
                } else {
                    ForEach($viewModel.generatedQuestions) { $question in
                        Section(header: Text("Question").font(.headline)) {
                            TextField("Question Text", text: $question.questionText, axis: .vertical)
                                .font(.body)
                                .lineLimit(2...5)
                            
                            ForEach(0..<question.options.count, id: \.self) { index in
                                HStack {
                                    Button(action: { question.correctOptionIndex = index }) {
                                        Image(systemName: question.correctOptionIndex == index ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(question.correctOptionIndex == index ? .green : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    TextField("Option \(index + 1)", text: Binding(
                                        get: { question.options[index] },
                                        set: { question.options[index] = $0 }
                                    ))
                                }
                            }
                            
                            TextField("Hint", text: Binding(
                                get: { question.hint ?? "" },
                                set: { question.hint = $0 }
                            ))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        }
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
            .task { await viewModel.fetchDropdownData() }
        }
    }
}
