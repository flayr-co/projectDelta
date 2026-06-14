//
//  LessonEditorView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseFirestore
import Observation

struct LessonEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var lessonTitle: String
    @State private var subjectName: String
    @State private var showTestBuilder: Bool = false
    
    @State private var lessonBlocks: [QuestionBlockModel] = []
    
    var lesson: Lesson
    
    init(lesson: Lesson = Lesson(id: nil, name: "", description: "", completed: false, lessonNumber: 1, pages: nil), subjectName: String = "") {
        self.lesson = lesson
        _lessonTitle = State(initialValue: lesson.name)
        _subjectName = State(initialValue: subjectName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Lesson Details")) {
                    TextField("Lesson Title", text: $lessonTitle)
                    TextField("Subject (e.g. Algebra)", text: $subjectName)
                }
                
                Section(header: Text("Lesson Content")) {
                    UniversalBlockEditorView(blocks: $lessonBlocks)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 8)
                }
                
                Section {
                    Button(action: {
                        showTestBuilder = true
                    }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Generate Test for This Lesson")
                                .fontWeight(.bold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.cyan)
                }
            }
            .navigationTitle(lesson.id?.isEmpty == false ? "Edit Lesson" : "New Lesson")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveLesson() }
                        .fontWeight(.bold)
                        .disabled(lessonTitle.isEmpty || subjectName.isEmpty)
                }
            }
            .onAppear {
                loadLessonBlocks()
            }
            .sheet(isPresented: $showTestBuilder) {
                AdminTestManagerView(subjectName: subjectName, lessonName: lessonTitle)
            }
        }
    }
    
    private func loadLessonBlocks() {
        if let data = lesson.description.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([QuestionBlockModel].self, from: data) {
            lessonBlocks = decoded
        } else if !lesson.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lessonBlocks = [QuestionBlockModel(type: QuestionBlockType.text.rawValue, content: lesson.description)]
        }
    }
    
    private func saveLesson() {
        Task {
            let db = Firestore.firestore()
            
            // Encode blocks to JSON string to store in description
            let finalDescription: String
            if let data = try? JSONEncoder().encode(lessonBlocks),
               let jsonString = String(data: data, encoding: .utf8) {
                finalDescription = jsonString
            } else {
                finalDescription = lessonBlocks.map { $0.content }.joined(separator: "\n")
            }
            
            var lessonData: [String: Any] = [
                "name": lessonTitle,
                "subject": subjectName,
                "description": finalDescription,
                "completed": lesson.completed,
                "lessonNumber": lesson.lessonNumber,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            do {
                if let existingId = lesson.id, !existingId.isEmpty {
                    try await db.collection("Lessons").document(existingId).setData(lessonData, merge: true)
                } else {
                    let newDocRef = db.collection("Lessons").document()
                    lessonData["id"] = newDocRef.documentID
                    try await newDocRef.setData(lessonData)
                }
                dismiss()
            } catch {
                print("Failed to save lesson edit: \(error.localizedDescription)")
            }
        }
    }
}
