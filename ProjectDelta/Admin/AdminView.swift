//
//  AdminView.swift
//  ProjectDelta
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
                        DatabaseToolsDashboard(viewModel: viewModel)
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

struct SubjectManagerDashboard: View {
    @Bindable var viewModel: AdminViewModel
    @State private var showingAddSubject = false
    @State private var newSubjectName = ""

    var body: some View {
        List {
            ForEach(viewModel.subjects) { subject in
                NavigationLink(destination: SubjectDetailAdminView(viewModel: viewModel, subject: subject)) {
                    HStack {
                        Image(systemName: subject.imageName)
                            .foregroundColor(.teal)
                        Text(subject.name)
                            .font(.headline)
                    }
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAddSubject = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Add Subject", isPresented: $showingAddSubject) {
            TextField("Subject Name", text: $newSubjectName)
            Button("Add") {
                Task {
                    await viewModel.addSubject(name: newSubjectName)
                    newSubjectName = ""
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

struct SubjectDetailAdminView: View {
    @Bindable var viewModel: AdminViewModel
    var subject: Subject
    
    var body: some View {
        List {
            Section("Lessons") {
                ForEach(viewModel.lessons) { lesson in
                    NavigationLink(destination: LessonEditorView(viewModel: viewModel, subject: subject, lesson: lesson)) {
                        Text("Lesson \(lesson.lessonNumber): \(lesson.name)")
                    }
                }
                NavigationLink("Add New Lesson", destination: LessonEditorView(viewModel: viewModel, subject: subject, lesson: nil))
                    .foregroundColor(.blue)
            }
            Section("Tests") {
                Text("Tests Management Active")
            }
        }
        .navigationTitle(subject.name)
        .task {
            // Safely extracts the ID as a String to pass to the ViewModel
            let subjectId = subject.id ?? subject.name
            await viewModel.fetchLessons(for: subjectId)
            await viewModel.fetchTests(for: subjectId)
        }
    }
}

struct DatabaseToolsDashboard: View {
    @Bindable var viewModel: AdminViewModel
    
    var body: some View {
        List {
            Section {
                Button {
                    Task {
                        // Triggers the migration script added to your AdminViewModel
                        await viewModel.rescueLegacyAlgebraLessons()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Migrate Legacy Algebra Lessons")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(viewModel.isProcessing)
            } header: {
                Text("Data Migrations")
            } footer: {
                Text("Executes a one-time database patch to inject the 'Linear Equations' subtopic into legacy Algebra lessons, ensuring compatibility with the new flat database architecture.")
            }
        }
    }
}

#Preview {
    AdminView()
}
