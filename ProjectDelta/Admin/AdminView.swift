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
                
                if viewModel.isProcessing {
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
            lessonsSection
            testsSection
        }
        .listStyle(.insetGrouped)
    }
    
    private var lessonsSection: some View {
        Section(header: Text("Lessons").font(.headline)) {
            NavigationLink(destination: LessonEditorView()) {
                Label("Create New Lesson", systemImage: "plus.circle.fill")
                    .foregroundColor(primaryAccent)
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
            NavigationLink(destination: AdminTestManagerView(subjectName: "Algebra", lessonName: "New Lesson")) {
                Label("Generate Recommended Test", systemImage: "wand.and.stars")
                    .foregroundColor(.cyan)
                    .font(.headline)
            }
            
            ForEach(viewModel.tests) { test in
                VStack(alignment: .leading, spacing: 4) {
                    // FIXED: Unwrapped ID with default value
                    Text(test.id ?? "Unknown ID")
                        .font(.body)
                        .fontWeight(.semibold)
                    
                    // FIXED: Unwrapped Subject with default value
                    Text(test.subject ?? "Uncategorized")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
