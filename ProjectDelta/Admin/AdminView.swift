//
//  AdminView.swift
//  ProjectDelta
//

import SwiftUI

struct AdminView: View {
    @State private var viewModel = AdminViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) var dismiss
    
    let emeraldAccent = Color(red: 0.18, green: 0.70, blue: 0.45)

    var themeBackground: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.11, blue: 0.10) : Color(red: 0.97, green: 0.96, blue: 0.94)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeBackground.ignoresSafeArea()
                
                if viewModel.isProcessing && viewModel.subjects.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(emeraldAccent)
                        Text("Loading Classroom Data...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.subjects.isEmpty {
                    ContentUnavailableView(
                        "No Subjects Found",
                        systemImage: "books.vertical.fill",
                        description: Text("Get started by creating a new subject for your students.")
                    )
                } else {
                    mainListContent
                }
            }
            .navigationTitle("Instructor Panel")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.fetchSubjects()
                await viewModel.fetchAllQuestions()
            }
        }
        .tint(emeraldAccent)
    }
    
    @ViewBuilder
    private var mainListContent: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to your dashboard.")
                        .font(.headline)
                    Text("Select a subject below to manage its curriculum, generate new practice tests, or review analytics.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            
            Section(header: Text("Your Subjects").font(.headline)) {
                ForEach(viewModel.subjects) { subject in
                    NavigationLink(destination: AdminSubjectDetailView(subject: subject, viewModel: viewModel)) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(emeraldAccent.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "folder.fill")
                                    .foregroundColor(emeraldAccent)
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(subject.name)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                Text(subject.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .padding(.bottom, 100)
    }
}

// MARK: - Subject Detail View

struct AdminSubjectDetailView: View {
    let subject: Subject
    @Bindable var viewModel: AdminViewModel
    
    @Environment(\.colorScheme) private var colorScheme
    let emeraldAccent = Color(red: 0.18, green: 0.70, blue: 0.45)
    
    var body: some View {
        List {
            Section {
                Text("Select a lesson below to edit its curriculum or build a practice test.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            }
            
            Section(header: Text("Lessons").font(.headline)) {
                NavigationLink(destination: LessonEditorView()) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(emeraldAccent)
                            .font(.title3)
                        Text("Create New Lesson")
                            .fontWeight(.medium)
                            .foregroundColor(emeraldAccent)
                    }
                    .padding(.vertical, 4)
                }
                
                ForEach(viewModel.lessons) { lesson in
                    NavigationLink(destination: AdminLessonDetailView(subject: subject, lesson: lesson, viewModel: viewModel)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.name)
                                .font(.body)
                                .fontWeight(.semibold)
                            Text(lesson.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(colorScheme == .dark ? Color(red: 0.12, green: 0.11, blue: 0.10) : Color(red: 0.97, green: 0.96, blue: 0.94))
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .padding(.bottom, 100)
        .task {
            if let id = subject.id {
                await viewModel.fetchLessons(for: id)
                await viewModel.fetchTests(for: id)
            }
        }
    }
}

// MARK: - Specific Lesson Details

struct AdminLessonDetailView: View {
    let subject: Subject
    let lesson: Lesson
    @Bindable var viewModel: AdminViewModel
    
    @Environment(\.colorScheme) private var colorScheme
    let emeraldAccent = Color(red: 0.18, green: 0.70, blue: 0.45)
    
    var existingTest: Test? {
        viewModel.tests.first(where: { $0.subtopic == lesson.name })
    }
    
    var body: some View {
        List {
            Section(header: Text("Curriculum").font(.headline)) {
                NavigationLink(destination: LessonEditorView(lesson: lesson)) {
                    HStack {
                        Image(systemName: "pencil.line")
                            .foregroundColor(.blue)
                        Text("Edit Lesson Content")
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section(header: Text("Assessment").font(.headline)) {
                if let test = existingTest {
                    NavigationLink(destination: AddTestView(subjectName: subject.name, lessonName: lesson.name, existingTest: test)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Edit Practice Test")
                                .font(.body)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Label("\(test.questionAmount) Qs", systemImage: "list.bullet.clipboard")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    NavigationLink(destination: AddTestView(subjectName: subject.name, lessonName: lesson.name)) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(emeraldAccent)
                            Text("Build Practice Test")
                                .fontWeight(.medium)
                                .foregroundColor(emeraldAccent)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(colorScheme == .dark ? Color(red: 0.12, green: 0.11, blue: 0.10) : Color(red: 0.97, green: 0.96, blue: 0.94))
        .navigationTitle(lesson.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
