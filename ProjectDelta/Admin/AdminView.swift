//
//  AdminView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 3/15/24.
//

import SwiftUI

struct AdminView: View {
    @State private var viewModel = AdminViewModel()
    @State private var adminTab: AdminTab = .content
    
    enum AdminTab {
        case content, questions, tools
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Admin Section", selection: $adminTab) {
                    Text("Content").tag(AdminTab.content)
                    Text("Questions").tag(AdminTab.questions)
                    Text("Tools").tag(AdminTab.tools)
                }
                .pickerStyle(.segmented)
                .padding()
                
                switch adminTab {
                case .content:
                    SubjectManagerView(viewModel: viewModel)
                case .questions:
                    QuestionManagerView(viewModel: viewModel)
                case .tools:
                    DatabaseToolsView(viewModel: viewModel)
                }
            }
            .navigationTitle("Admin Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isProcessing {
                        ProgressView()
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

struct SubjectManagerView: View {
    @Bindable var viewModel: AdminViewModel
    @State private var newSubjectName = ""
    @State private var showingAddSubject = false
    
    var body: some View {
        List {
            Section("Subjects") {
                ForEach(viewModel.subjects) { subject in
                    NavigationLink(subject.name) {
                        LessonManagerView(viewModel: viewModel, subject: subject)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        if let id = viewModel.subjects[index].id {
                            Task { await viewModel.deleteSubject(id: id) }
                        }
                    }
                }
            }
            
            Section {
                Button("Add New Subject") { showingAddSubject = true }
            }
        }
        .alert("New Subject", isPresented: $showingAddSubject) {
            TextField("Name", text: $newSubjectName)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                Task {
                    await viewModel.addSubject(name: newSubjectName)
                    newSubjectName = ""
                }
            }
        }
    }
}

struct LessonManagerView: View {
    var viewModel: AdminViewModel
    var subject: Subject
    @State private var newLessonName = ""
    
    var body: some View {
        List {
            Section("Lessons for \(subject.name)") {
                ForEach(viewModel.lessons) { lesson in
                    NavigationLink("\(lesson.name) (\(lesson.pages?.count ?? 0) pages)") {
                        PageEditorView(viewModel: viewModel, subject: subject, lesson: lesson)
                    }
                }
            }
            
            Section("Quick Add Lesson") {
                HStack {
                    TextField("Lesson Name", text: $newLessonName)
                    Button("Add") {
                        Task {
                            await viewModel.addLesson(subjectId: subject.id ?? "", name: newLessonName)
                            newLessonName = ""
                        }
                    }
                    .disabled(newLessonName.isEmpty)
                }
            }
        }
        .task {
            if let id = subject.id {
                await viewModel.fetchLessons(for: id)
            }
        }
        .navigationTitle(subject.name)
    }
}

struct PageEditorView: View {
    var viewModel: AdminViewModel
    var subject: Subject
    var lesson: Lesson
    
    @State private var pageNumber: Int = 1
    @State private var content: String = ""
    @State private var example: String = ""
    @State private var explanation: String = ""
    @State private var graphics: String = ""
    @State private var readyButton = false
    
    var body: some View {
        Form {
            Section("Page Order") {
                Stepper("Page Number: \(pageNumber)", value: $pageNumber, in: 1...100)
                Toggle("Show 'Ready' Button", isOn: $readyButton)
            }
            
            Section("Content") {
                TextEditor(text: $content)
                    .frame(height: 150)
                    .onChange(of: content) { _, newValue in
                        content = newValue.replacingOccurrences(of: "^2", with: "²")
                    }
            }
            
            Section("Example & Explanation") {
                TextEditor(text: $example)
                    .frame(height: 100)
                    .onChange(of: example) { _, newValue in
                        example = newValue.replacingOccurrences(of: "^2", with: "²")
                    }
                TextEditor(text: $explanation)
                    .frame(height: 100)
                    .onChange(of: explanation) { _, newValue in
                        explanation = newValue.replacingOccurrences(of: "^2", with: "²")
                    }
            }
            
            Button("Add Page to Lesson") {
                // Corrected parameter order: content must precede pageNumber
                let newPage = Page(
                    content: content,
                    pageNumber: pageNumber,
                    readyButtonDisplayed: readyButton,
                    example: example.isEmpty ? nil : example,
                    explanation: explanation.isEmpty ? nil : explanation,
                    graphics: graphics.isEmpty ? nil : graphics
                )
                
                Task {
                    if let sId = subject.id, let lId = lesson.id {
                        await viewModel.addPageToFirestore(subjectId: sId, lessonId: lId, page: newPage)
                    }
                }
            }
        }
        .navigationTitle("Add Page")
        .alert("Success", isPresented: .init(get: { viewModel.showSubmissionSuccessAlert }, set: { viewModel.showSubmissionSuccessAlert = $0 })) {
            Button("OK") {
                content = ""; example = ""; explanation = ""; graphics = ""
                pageNumber += 1
            }
        }
    }
}

struct QuestionManagerView: View {
    @Bindable var viewModel: AdminViewModel
    
    var body: some View {
        List {
            ForEach(viewModel.questions) { question in
                VStack(alignment: .leading) {
                    Text(question.questionText ?? "No text")
                        .font(.subheadline).bold()
                        .lineLimit(2)
                    Text("\(question.subject) • \(question.subtopic ?? "No Subtopic")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    if let id = viewModel.questions[index].id {
                        Task { await viewModel.deleteQuestion(id: id) }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.fetchAllQuestions()
        }
    }
}

struct DatabaseToolsView: View {
    var viewModel: AdminViewModel
    
    var body: some View {
        List {
            Section(header: Text("Migrations"), footer: Text(viewModel.migrationMessage)) {
                Button("Fix Algebra -> Linear Equations") {
                    Task { await viewModel.migrateAlgebraSubtopics() }
                }
                .foregroundColor(.red)
            }
            
            Section("Stats") {
                LabeledContent("Total Subjects", value: "\(viewModel.subjects.count)")
                LabeledContent("Total Questions", value: "\(viewModel.questions.count)")
            }
        }
    }
}

#Preview {
    AdminView()
}
