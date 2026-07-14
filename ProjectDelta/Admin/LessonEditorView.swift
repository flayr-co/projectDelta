//
//  LessonEditorView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseFirestore
import Observation

struct LessonEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
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
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lesson.id?.isEmpty == false ? "Edit Curriculum" : "Author New Lesson")
                            .font(.title)
                            .fontWeight(.heavy)
                        Text("Construct your educational material using the dynamic block editor.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Metadata Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "text.book.closed.fill")
                                .foregroundColor(.teal)
                            Text("Lesson Metadata")
                                .font(.headline)
                        }
                        
                        Divider()
                        
                        TextField("Enter Lesson Title...", text: $lessonTitle)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(12)
                            .background(Color.platformSecondarySystemBackground)
                            .cornerRadius(10)
                        
                        HStack {
                            Text("Parent Subject")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                            Spacer()
                            Text(subject.name)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.teal.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.platformSystemBackground)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
                    .padding(.horizontal)
                    
                    // Editor Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "square.dashed.inset.filled")
                                .foregroundColor(.purple)
                            Text("Content Blocks")
                                .font(.headline)
                        }
                        
                        Divider()
                        
                        UniversalBlockEditorView(blocks: $lessonBlocks)
                    }
                    .padding()
                    .background(Color.platformSystemBackground)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 80)
                }
            }
            .background(Color.platformSystemGroupedBackground.ignoresSafeArea())
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(.secondary)
                        
                        Button("Save") { saveLesson() }
                            .fontWeight(.bold)
                            .buttonStyle(.borderedProminent)
                            .tint(.teal)
                            .disabled(lessonTitle.isEmpty)
                            .clipShape(Capsule())
                    }
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveLesson() }
                        .fontWeight(.bold)
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                        .disabled(lessonTitle.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                #endif
            }
            .onAppear {
                loadLessonBlocks()
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: { showTestBuilder = true }) {
                    HStack {
                        Image(systemName: "wand.and.stars.inverse")
                            .font(.title3)
                        Text("Generate Linked Test")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: Color.purple.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .background(Color.platformSystemGroupedBackground.opacity(0.95))
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
            guard let subjectId = subject.id, !subjectId.isEmpty else { return }
            
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
