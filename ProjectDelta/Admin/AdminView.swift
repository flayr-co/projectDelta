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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
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

// MARK: - Subject Detail View (Restored Slider Tab)

struct AdminSubjectDetailView: View {
    let subject: Subject
    @Bindable var viewModel: AdminViewModel
    
    @Environment(\.colorScheme) private var colorScheme
    let emeraldAccent = Color(red: 0.18, green: 0.70, blue: 0.45)
    
    @State private var selectedTab: Int = 0 // 0 = Lessons, 1 = Tests
    
    var themeBackground: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.11, blue: 0.10) : Color(red: 0.97, green: 0.96, blue: 0.94)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Curriculum", selection: $selectedTab) {
                Text("Lessons").tag(0)
                Text("Tests").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            .background(themeBackground)
            
            List {
                if selectedTab == 0 {
                    lessonsSection
                } else {
                    testsSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeBackground)
        }
        .navigationTitle(subject.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if let id = subject.id {
                await viewModel.fetchLessons(for: id)
                await viewModel.fetchTests(for: id)
            }
        }
    }
    
    private var lessonsSection: some View {
        Section(header: Text("Curriculum Content").font(.headline)) {
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
                NavigationLink(destination: LessonEditorView(lesson: lesson)) {
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
    
    private var testsSection: some View {
        Section(header: Text("Assessments").font(.headline)) {
            NavigationLink(destination: AddTestView(subjectName: subject.name, lessonName: viewModel.lessons.first?.name ?? "New Lesson")) {
                HStack {
                    Image(systemName: "pencil.and.list.clipboard")
                        .foregroundColor(emeraldAccent)
                        .font(.title3)
                    Text("Build Manual Assessment")
                        .fontWeight(.medium)
                        .foregroundColor(emeraldAccent)
                }
                .padding(.vertical, 4)
            }
            
            ForEach(viewModel.tests) { test in
                NavigationLink(destination: AddTestView(subjectName: subject.name, lessonName: test.subtopic ?? "Unknown Lesson", existingTest: test)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(test.subtopic ?? "Untitled") Test")
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
            }
        }
    }
}
