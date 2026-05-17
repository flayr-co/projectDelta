//
//  AdminView.swift
//  ProjectDelta
//

import SwiftUI

struct AdminView: View {
    @State private var viewModel = AdminViewModel()
    @Environment(\.colorScheme) private var colorScheme
    
    let primaryAccent = Color.teal

    var backgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.systemBackground) : Color(red: 0.96, green: 0.94, blue: 0.90)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                List {
                    Section {
                        if viewModel.subjects.isEmpty {
                            Text("No subjects found. Add one to begin.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(viewModel.subjects) { subject in
                                NavigationLink(destination: SubjectDetailAdminView(viewModel: viewModel, subject: subject)) {
                                    HStack {
                                        Image(systemName: subject.imageName)
                                            .foregroundColor(primaryAccent)
                                            .font(.title3)
                                        Text(subject.name)
                                            .font(.headline)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    let subject = viewModel.subjects[index]
                                    if let id = subject.id {
                                        Task { await viewModel.deleteSubject(id: id) }
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Curriculum Management")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    
                    Section {
                        AddSubjectButton(viewModel: viewModel)
                    }
                    
                    Section {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.rescueLegacyAlgebraLessons()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Migrate Legacy Algebra Data")
                            }
                        }
                        .disabled(viewModel.isProcessing)
                    } header: {
                        Text("Database Tools")
                    } footer: {
                        Text("Use this tool only if you have older database entries that need formatting.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Teacher Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isProcessing {
                        ProgressView().tint(primaryAccent)
                    }
                }
            }
            .tint(primaryAccent)
        }
    }
}

struct AddSubjectButton: View {
    @Bindable var viewModel: AdminViewModel
    @State private var showingAddSubject = false
    @State private var newSubjectName = ""
    
    var body: some View {
        Button {
            showingAddSubject = true
        } label: {
            HStack {
                Image(systemName: "plus.app.fill")
                Text("Create New Subject")
                    .fontWeight(.bold)
            }
            .foregroundColor(.teal)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        }
        .alert("New Subject", isPresented: $showingAddSubject) {
            TextField("Subject Name", text: $newSubjectName)
            Button("Create") {
                Task {
                    await viewModel.addSubject(name: newSubjectName)
                    newSubjectName = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newSubjectName = ""
            }
        } message: {
            Text("Enter the name of the new subject (e.g., Calculus, Physics).")
        }
    }
}

struct SubjectDetailAdminView: View {
    @Bindable var viewModel: AdminViewModel
    var subject: Subject
    
    var body: some View {
        List {
            Section {
                if viewModel.lessons.isEmpty {
                    Text("No lessons currently in this subject.")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                
                ForEach(viewModel.lessons) { lesson in
                    NavigationLink(destination: LessonEditorView(viewModel: viewModel, subject: subject, lesson: lesson)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lesson \(lesson.lessonNumber): \(lesson.name)")
                                .font(.headline)
                            Text(lesson.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteLesson)
                
                NavigationLink(destination: LessonEditorView(viewModel: viewModel, subject: subject, lesson: nil)) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Build New Lesson")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                }
            } header: {
                Text("Lessons")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            
            Section {
                if viewModel.tests.isEmpty {
                    Text("No tests currently in this subject.")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                
                ForEach(viewModel.tests) { test in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Test #\(test.testIdentifier)")
                            .font(.headline)
                        Text("\(test.questionAmount) Qs | \(test.timeLimit) mins | Lesson: \(test.subtopic ?? "General")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteTest)
                
                NavigationLink(destination: AddTestView(viewModel: viewModel, subject: subject)) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create New Test")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                }
            } header: {
                Text("Tests")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
        }
        .navigationTitle(subject.name)
        .task {
            let subjectId = subject.id ?? subject.name
            await viewModel.fetchLessons(for: subjectId)
            await viewModel.fetchTests(for: subjectId)
        }
    }
    
    private func deleteLesson(at offsets: IndexSet) {
        guard let subjectId = subject.id ?? subject.name as String? else { return }
        for index in offsets {
            let lesson = viewModel.lessons[index]
            if let lessonId = lesson.id {
                Task {
                    await viewModel.deleteLesson(subjectId: subjectId, lessonId: lessonId)
                }
            }
        }
    }
    
    private func deleteTest(at offsets: IndexSet) {
        guard let subjectId = subject.id ?? subject.name as String? else { return }
        for index in offsets {
            let test = viewModel.tests[index]
            if let testId = test.id {
                Task {
                    await viewModel.deleteTest(subjectId: subjectId, testId: testId)
                }
            }
        }
    }
}
