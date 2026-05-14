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
    case content, tools
}

let backgroundColor = Color(red: 0.96, green: 0.94, blue: 0.90)
let primaryAccent = Color.teal

var body: some View {
    NavigationStack {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Picker("Admin Section", selection: $adminTab) {
                    Text("Curriculum").tag(AdminTab.content)
                    Text("Database").tag(AdminTab.tools)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color(uiColor: .systemBackground).opacity(0.8))
                
                switch adminTab {
                case .content:
                    SubjectManagerDashboard(viewModel: viewModel)
                case .tools:
                    DatabaseToolsView(viewModel: viewModel)
                }
            }
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

// MARK: - Subject Manager Dashboard

struct SubjectManagerDashboard: View {
@Bindable var viewModel: AdminViewModel
@State private var showingAddSubject = false
@State private var newSubjectName = ""

var body: some View {
    Group {
        if viewModel.subjects.isEmpty && !viewModel.isProcessing {
            ContentUnavailableView(label: {
                Label("No Subjects Found", systemImage: "books.vertical.fill")
            }, description: {
                Text("Begin building your curriculum by adding a core subject like Algebra or Physics.")
            }, actions: {
                Button("Create First Subject") { showingAddSubject = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.emerald)
            })
        } else {
            List {
                Section(header: Text("Academic Subjects").font(.subheadline.bold())) {
                    ForEach(viewModel.subjects) { subject in
                        NavigationLink(destination: SubjectDetailDashboard(viewModel: viewModel, subject: subject)) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [.teal, .green], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(subject.name)
                                        .font(.headline)
                                    Text("Manage lessons & tests")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section {
                    Button(action: { showingAddSubject = true }) {
                        Label("Add New Subject", systemImage: "plus.circle.fill")
                            .foregroundStyle(.teal)
                            .font(.headline)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }
    .alert("New Subject", isPresented: $showingAddSubject) {
        TextField("Subject Name (e.g., Algebra)", text: $newSubjectName)
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

// MARK: - Subject Detail (Tests & Lessons)

struct SubjectDetailDashboard: View {
@Bindable var viewModel: AdminViewModel
var subject: Subject
@State private var selectedMode: Mode = .lessons

enum Mode { case lessons, tests }

var body: some View {
    VStack(spacing: 0) {
        Picker("Mode", selection: $selectedMode) {
            Text("Course Lessons").tag(Mode.lessons)
            Text("Assessments").tag(Mode.tests)
        }
        .pickerStyle(.segmented)
        .padding()
        .background(Color(uiColor: .systemBackground))
        
        if selectedMode == .lessons {
            LessonListAdminView(viewModel: viewModel, subject: subject)
        } else {
            TestListAdminView(viewModel: viewModel, subject: subject)
        }
    }
    .background(Color(red: 0.96, green: 0.94, blue: 0.90).ignoresSafeArea())
    .navigationTitle(subject.name)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
        Task {
            await viewModel.fetchLessons(for: subject.id ?? "")
            await viewModel.fetchTests(for: subject.id ?? "")
        }
    }
}
}

// MARK: - Lessons View

struct LessonListAdminView: View {
var viewModel: AdminViewModel
var subject: Subject
@State private var showingAddLesson = false
@State private var lessonName = ""

var body: some View {
    List {
        if viewModel.lessons.isEmpty {
            ContentUnavailableView("No Lessons", systemImage: "doc.text.image", description: Text("Create lessons using text, LaTeX, and dynamic graphs."))
                .listRowBackground(Color.clear)
        } else {
            ForEach(viewModel.lessons) { lesson in
                NavigationLink(destination: LessonEditorView(viewModel: viewModel, subject: subject, lesson: lesson)) {
                    VStack(alignment: .leading) {
                        Text(lesson.name).font(.headline)
                        Text("\(lesson.pages?.count ?? 0) Interactive Pages")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        
        Button { showingAddLesson = true } label: {
            Label("Create New Lesson", systemImage: "plus.rectangle.on.rectangle")
                .foregroundStyle(Color.emerald)
                .bold()
        }
    }
    .scrollContentBackground(.hidden)
    .alert("New Lesson", isPresented: $showingAddLesson) {
        TextField("Lesson Name", text: $lessonName)
        Button("Cancel", role: .cancel) { }
        Button("Add") {
            Task {
                await viewModel.addLesson(subjectId: subject.id ?? "", name: lessonName, description: "")
                lessonName = ""
            }
        }
    }
}
}

// MARK: - Tests View

struct TestListAdminView: View {
var viewModel: AdminViewModel
var subject: Subject

// Group and sort the tests beforehand to prevent Swift from timing out on type-checking
var groupedAndSortedTests: [(String, [Test])] {
    let grouped = Dictionary(grouping: viewModel.tests, by: { $0.subtopic ?? "General" })
    return grouped.sorted(by: { $0.key < $1.key })
}

var body: some View {
    List {
        if viewModel.tests.isEmpty {
            ContentUnavailableView("No Tests", systemImage: "checkmark.seal.fill", description: Text("Generate tests and populate them with questions."))
                .listRowBackground(Color.clear)
        } else {
            ForEach(groupedAndSortedTests, id: \.0) { subtopic, tests in
                Section(header: Text(subtopic).font(.headline)) {
                    ForEach(tests, id: \.id) { test in
                        NavigationLink(destination: AddQuestionView(viewModel: viewModel, subject: subject, test: test)) {
                            HStack {
                                Image(systemName: "pencil.and.list.clipboard")
                                    .foregroundStyle(.teal)
                                VStack(alignment: .leading) {
                                    Text("Test Identifier: \(test.testIdentifier)")
                                        .font(.subheadline).bold()
                                    Text("\(test.questionAmount) Questions • \(test.timeLimit) mins")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        NavigationLink(destination: AddTestView(viewModel: viewModel, subject: subject)) {
            Label("Generate New Test", systemImage: "doc.badge.plus")
                .foregroundStyle(Color.emerald)
                .bold()
        }
    }
    .scrollContentBackground(.hidden)
}
}

// MARK: - Database Tools View

struct DatabaseToolsView: View {
@Bindable var viewModel: AdminViewModel

var body: some View {
    List {
        Section("Database Statistics") {
            LabeledContent("Total Subjects", value: "\(viewModel.subjects.count)")
            LabeledContent("Total Global Questions", value: "\(viewModel.questions.count)")
        }
    }
    .scrollContentBackground(.hidden)
}
}

// Helper color extension
extension Color {
static let emerald = Color(red: 0.31, green: 0.78, blue: 0.47)
}
