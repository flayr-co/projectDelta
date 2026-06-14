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
        try? await Task.sleep(for: .seconds(1.0))
        
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
        withAnimation { showEditor = true }
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
    @Environment(\.dismiss) var dismiss

    init(subjectName: String, lessonName: String, existingTest: Test? = nil) {
        _viewModel = State(wrappedValue: AdminTestManagerViewModel(subject: subjectName, lesson: lessonName, test: existingTest))
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
            // Protects the layout from colliding with the floating tab bar
            .safeAreaPadding(.bottom, 120)
            .background(Color.platformSystemGroupedBackground.ignoresSafeArea())
            .navigationTitle(viewModel.existingTest != nil ? "Edit Test" : "Test Generator")
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
            // Header Hero
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
            
            // Configuration Card
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
            
            // Generate Button
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
            .disabled(
                (viewModel.subjectName == "+ Add New Subject" && viewModel.customSubjectName.isEmpty) ||
                (viewModel.lessonName == "+ Add New Lesson" && viewModel.customLessonName.isEmpty) ||
                viewModel.isGenerating
            )
            .opacity(viewModel.isGenerating ? 0.7 : 1.0)
        }
    }
    
    @ViewBuilder
    private var editorSection: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Test Builder")
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
                    .background(Color.teal.opacity(0.15))
                    .foregroundColor(.teal)
                    .cornerRadius(8)
            }
            
            // Question List
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
                .padding()
                .background(Color.platformSystemBackground)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            }
            
            // Add Another Question Button
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
            
            // Save Test Button
            Button(action: {
                Task {
                    await viewModel.saveTestToDatabase()
                    dismiss()
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 56)
                        .shadow(color: .green.opacity(0.3), radius: 10, y: 5)
                    
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Publish Test to Database")
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
}
