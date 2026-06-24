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
        ZStack {
#if os(macOS)
            Color.platformSystemGroupedBackground.ignoresSafeArea()
#else
            themeBackground.ignoresSafeArea()
#endif
            
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
                Group {
#if os(macOS)
                    macOSMainContent
#else
                    iOSMainContent
#endif
                }
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
        .tint(emeraldAccent)
    }
    
    // MARK: - DESKTOP MAIN LAYOUT (macOS)
    #if os(macOS)
    @ViewBuilder
    private var macOSMainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {
                // Header Welcome Block
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to your dashboard.")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Select a subject below to manage its curriculum, generate new practice tests, or review analytics.")
                        .font(.system(.title3, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 16)
                
                // Subjects Grid
                Text("Your Subjects")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                
                let desktopColumns = [
                    GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 24)
                ]
                
                LazyVGrid(columns: desktopColumns, spacing: 24) {
                    ForEach(viewModel.subjects) { subject in
                        NavigationLink(destination: AdminSubjectDetailView(subject: subject, viewModel: viewModel)) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(emeraldAccent.opacity(0.15))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(emeraldAccent)
                                        .font(.title2)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(subject.name)
                                        .font(.system(.title3, design: .rounded, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(subject.description)
                                        .font(.system(.body, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                            }
                            .padding(20)
                            .background(Color.platformSystemBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(40)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    #endif

    // MARK: - MOBILE MAIN LAYOUT (iOS)
    #if os(iOS)
    @ViewBuilder
    private var iOSMainContent: some View {
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
    #endif
}

// MARK: - Subject Detail View

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
        Group {
            #if os(macOS)
            macOSDetailLayout
            #else
            iOSDetailLayout
            #endif
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
    
    // MARK: - DESKTOP DETAIL LAYOUT (macOS)
    #if os(macOS)
    private var macOSDetailLayout: some View {
        VStack(spacing: 0) {
            Picker("Curriculum", selection: $selectedTab) {
                Text("Lessons").tag(0)
                Text("Tests").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
            .background(Color.platformSystemBackground)
            
            Divider()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if selectedTab == 0 {
                        macOSLessonsSection
                    } else {
                        macOSTestsSection
                    }
                }
                .padding(40)
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(Color.platformSystemGroupedBackground)
        }
    }
    
    private var macOSLessonsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Curriculum Content")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            
            NavigationLink(destination: LessonEditorView(subject: subject)) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(emeraldAccent)
                        .font(.title2)
                    Text("Create New Lesson")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundColor(emeraldAccent)
                    Spacer()
                }
                .padding(20)
                .background(Color.platformSystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
            }
            .buttonStyle(.plain)
            
            ForEach(viewModel.lessons) { lesson in
                NavigationLink(destination: LessonEditorView(lesson: lesson, subject: subject)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lesson.name)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                        Text(lesson.description)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.platformSystemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var macOSTestsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Assessments")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            
            NavigationLink(destination: AddTestView(subject: subject, lessonName: viewModel.lessons.first?.name ?? "New Lesson")) {
                HStack {
                    Image(systemName: "pencil.and.list.clipboard")
                        .foregroundColor(emeraldAccent)
                        .font(.title2)
                    Text("Build Manual Assessment")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundColor(emeraldAccent)
                    Spacer()
                }
                .padding(20)
                .background(Color.platformSystemBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
            }
            .buttonStyle(.plain)
            
            ForEach(viewModel.tests) { test in
                NavigationLink(destination: AddTestView(subject: subject, lessonName: test.subtopic ?? "Unknown Lesson", existingTest: test)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(test.subtopic ?? "Untitled") Test")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                        
                        HStack {
                            Label("\(test.questionAmount) Qs", systemImage: "list.bullet.clipboard")
                        }
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.platformSystemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
    #endif

    // MARK: - MOBILE DETAIL LAYOUT (iOS)
    #if os(iOS)
    private var iOSDetailLayout: some View {
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
        .background(themeBackground.ignoresSafeArea())
    }
    
    private var lessonsSection: some View {
        Section(header: Text("Curriculum Content").font(.headline)) {
            NavigationLink(destination: LessonEditorView(subject: subject)) {
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
                NavigationLink(destination: LessonEditorView(lesson: lesson, subject: subject)) {
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
            NavigationLink(destination: AddTestView(subject: subject, lessonName: viewModel.lessons.first?.name ?? "New Lesson")) {
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
                NavigationLink(destination: AddTestView(subject: subject, lessonName: test.subtopic ?? "Unknown Lesson", existingTest: test)) {
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
    #endif
}
