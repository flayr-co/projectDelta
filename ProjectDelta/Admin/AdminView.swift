//
//  AdminView.swift
//  ProjectDelta
//

import SwiftUI

struct AdminView: View {
    @State private var viewModel = AdminViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) var dismiss
    
    let primaryAccent = Color.teal

    var backgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.systemBackground) : Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                // Show progress view only if processing and no subjects exist yet
                if viewModel.isProcessing && viewModel.subjects.isEmpty {
                    ProgressView("Loading Admin Data...")
                } else {
                    mainListContent
                }
            }
            .navigationTitle("Admin Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .tint(.red)
                }
            }
            .task {
                await viewModel.fetchSubjects()
                await viewModel.fetchAllQuestions()
            }
        }
    }
    
    // MARK: - Sub-Expressions
    
    @ViewBuilder
    private var mainListContent: some View {
        List {
            Section(header: Text("Subjects").font(.headline)) {
                ForEach(viewModel.subjects) { subject in
                    NavigationLink(destination: AdminSubjectDetailView(subject: subject, viewModel: viewModel)) {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(primaryAccent)
                                .font(.title3)
                            
                            VStack(alignment: .leading) {
                                Text(subject.name)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                Text(subject.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Detail View

struct AdminSubjectDetailView: View {
    let subject: Subject
    @Bindable var viewModel: AdminViewModel
    
    var body: some View {
        List {
            lessonsSection
            testsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(subject.name)
        .task {
            // Fetch the specific data for the chosen subject
            if let id = subject.id {
                await viewModel.fetchLessons(for: id)
                await viewModel.fetchTests(for: id)
            }
        }
    }
    
    private var lessonsSection: some View {
        Section(header: Text("Lessons").font(.headline)) {
            NavigationLink(destination: LessonEditorView()) {
                Label("Create New Lesson", systemImage: "plus.circle.fill")
                    .foregroundColor(.teal)
                    .font(.headline)
            }
            
            ForEach(viewModel.lessons) { lesson in
                NavigationLink(destination: LessonEditorView(lesson: lesson)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lesson.name)
                            .font(.body)
                            .fontWeight(.semibold)
                        Text(lesson.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var testsSection: some View {
        Section(header: Text("Test Generator").font(.headline)) {
            // Passed in the dynamic subject name instead of hardcoded "Algebra"
            NavigationLink(destination: AdminTestManagerView(subjectName: subject.name, lessonName: "New Lesson")) {
                Label("Generate Recommended Test", systemImage: "wand.and.stars")
                    .foregroundColor(.cyan)
                    .font(.headline)
            }
            
            ForEach(viewModel.tests) { test in
                VStack(alignment: .leading, spacing: 4) {
                    Text(test.id ?? "Unknown ID")
                        .font(.body)
                        .fontWeight(.semibold)
                    
                    Text(test.subject ?? "Uncategorized")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
