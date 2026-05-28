//
//  LessonEditorView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseFirestore
import Observation

enum ContentBlockType: String, CaseIterable {
    case text = "Text"
    case math = "Equation"
    case graph = "Graph"
}

enum GraphInputType: String, CaseIterable {
    case equation = "Function (y = f(x))"
    case points = "Points Data"
}

struct LessonEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var lessonTitle: String
    @State private var subjectName: String
    @State private var showTestBuilder: Bool = false
    
    // Assumes you pass in an existing lesson to edit, or a blank one to create
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveLesson() }
                        .fontWeight(.bold)
                        .disabled(lessonTitle.isEmpty || subjectName.isEmpty)
                }
            }
            .sheet(isPresented: $showTestBuilder) {
                AdminTestManagerView(subjectName: subjectName, lessonName: lessonTitle)
            }
        }
    }
    
    private func saveLesson() {
        Task {
            let db = Firestore.firestore()
            
            var lessonData: [String: Any] = [
                "name": lessonTitle,
                "subject": subjectName,
                "description": lesson.description,
                "completed": lesson.completed,
                "lessonNumber": lesson.lessonNumber,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            do {
                if let existingId = lesson.id, !existingId.isEmpty {
                    // Merges the updated data into the existing designated lesson
                    try await db.collection("Lessons").document(existingId).setData(lessonData, merge: true)
                    print("Lesson successfully edited and updated!")
                } else {
                    // Generates a new lesson if one doesn't exist
                    let newDocRef = db.collection("Lessons").document()
                    lessonData["id"] = newDocRef.documentID
                    try await newDocRef.setData(lessonData)
                    print("New lesson successfully created!")
                }
                dismiss()
            } catch {
                print("Failed to save lesson edit: \(error.localizedDescription)")
            }
        }
    }
}
