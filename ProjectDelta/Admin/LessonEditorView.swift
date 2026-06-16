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
    @State private var showTestBuilder: Bool = false
    @State private var lessonBlocks: [QuestionBlockModel] = []
    
    var lesson: Lesson
    var subject: Subject
    
    init(lesson: Lesson = Lesson(id: nil, name: "", description: "", completed: false, lessonNumber: 1, pages: nil), subject: Subject) {
        self.lesson = lesson
        self.subject = subject
        _lessonTitle = State(initialValue: lesson.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Lesson Details")) {
                    TextField("Lesson Title", text: $lessonTitle)
                    
                    HStack {
                        Text("Subject Architecture")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(subject.name)
                            .fontWeight(.semibold)
                    }
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
                        .disabled(lessonTitle.isEmpty)
                }
            }
            .onAppear {
                loadLessonBlocks()
            }
            .sheet(isPresented: $showTestBuilder) {
                NavigationStack {
                    AddTestView(subject: subject, lessonName: lessonTitle)
                }
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
            guard let subjectId = subject.id, !subjectId.isEmpty else {
                print("Error: Immutable Subject ID missing.")
                return
            }
            
            let finalDescription: String
            if let data = try? JSONEncoder().encode(lessonBlocks),
               let jsonString = String(data: data, encoding: .utf8) {
                finalDescription = jsonString
            } else {
                finalDescription = lessonBlocks.map { $0.content }.joined(separator: "\n")
            }
            
            var lessonData: [String: Any] = [
                "name": lessonTitle,
                "subject": subject.name,
                "description": finalDescription,
                "completed": lesson.completed,
                "lessonNumber": lesson.lessonNumber,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            do {
                if let existingId = lesson.id, !existingId.isEmpty {
                    try await db.collection("Subjects").document(subjectId).collection("Lessons").document(existingId).setData(lessonData, merge: true)
                } else {
                    let newDocRef = db.collection("Subjects").document(subjectId).collection("Lessons").document()
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
