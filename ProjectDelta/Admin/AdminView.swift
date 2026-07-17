//
//  AdminView.swift
//  ProjectDelta
//

import SwiftUI
import Observation

struct AdminView: View {
    @State private var viewModel = AdminViewModel()
    @State private var selectedSubject: Subject?
    @Environment(\.dismiss) var dismiss
    
    // UI Constants
    private let primaryTeal = Color(red: 0.12, green: 0.65, blue: 0.65)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Curriculum Architect")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                    Text("Manage your subject hierarchy, lessons, and assessment database.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                #if os(macOS)
                .padding(.top, 32)
                #else
                .padding(.top, 16)
                #endif
                .padding(.bottom, 16)
                
                // Interactive List
                List {
                    ForEach(Array(viewModel.subjects.enumerated()), id: \.element.id) { index, subject in
                        SubjectAdminCard(subject: subject, displayIndex: index + 1, viewModel: viewModel, onEdit: {
                            selectedSubject = subject
                        })
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                        .listRowBackground(Color.clear)
                    }
                    .onMove { source, destination in
                        viewModel.updateSubjectOrder(from: source, to: destination)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                // Hoisted navigation destination resolves all console warnings
                .navigationDestination(item: $selectedSubject) { subject in
                    LessonManagerView(subject: subject, viewModel: viewModel)
                }
            }
            .background(Color.platformSystemGroupedBackground)
            .safeAreaInset(edge: .top) {
                #if os(macOS)
                Color.clear.frame(height: 24)
                #else
                Color.clear.frame(height: 0)
                #endif
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { /* Add Global Subject Logic */ }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(primaryTeal)
                    }
                }
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                #endif
            }
            .overlay {
                if viewModel.isProcessing {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("Syncing Database...")
                            .padding(20)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
}

// MARK: - Refined Subject Card
struct SubjectAdminCard: View {
    let subject: Subject
    let displayIndex: Int
    @Bindable var viewModel: AdminViewModel
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Sequence Indicator
                Text("\(displayIndex)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.teal.opacity(0.4))
                    .frame(width: 32, alignment: .leading)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.teal.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: subject.imageName)
                        .font(.title2)
                        .foregroundColor(.teal)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.name)
                        .font(.headline)
                    Text("\(subject.lessonCount) Lessons")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .foregroundColor(.secondary.opacity(0.3))
            }
            
            Divider()
            
            HStack(spacing: 12) {
                Button("Edit Curriculum") { onEdit() }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                
                Spacer()
                
                Button(role: .destructive, action: { Task { await viewModel.deleteSubject(id: subject.id ?? "") } }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(20)
        .background(Color.platformSystemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Lesson Manager
struct LessonManagerView: View {
    let subject: Subject
    @Bindable var viewModel: AdminViewModel
    @State private var showingAddLesson = false
    @State private var selectedLesson: Lesson?
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(Array(viewModel.lessons.enumerated()), id: \.element.id) { index, lesson in
                    LessonAdminCard(lesson: lesson, displayIndex: index + 1, onEdit: {
                        selectedLesson = lesson
                    }, onDelete: {
                        Task { await viewModel.deleteLesson(subjectId: subject.id ?? "", lessonId: lesson.id ?? "") }
                    })
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                    .listRowBackground(Color.clear)
                }
                .onMove { source, destination in
                    viewModel.updateLessonOrder(subjectId: subject.id ?? "", from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationDestination(item: $selectedLesson) { lesson in
                LessonEditorView(lesson: lesson, subject: subject)
            }
        }
        .background(Color.platformSystemGroupedBackground)
        .navigationTitle(subject.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await viewModel.fetchLessons(for: subject.id ?? "") }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Lesson") { showingAddLesson = true }
            }
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            #endif
        }
        .sheet(isPresented: $showingAddLesson) {
            // Reusing LessonEditorView for creation. Adjust if your logic dictates otherwise.
            LessonEditorView(subject: subject)
        }
    }
}

// MARK: - Refined Lesson Card
struct LessonAdminCard: View {
    let lesson: Lesson
    let displayIndex: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Text("\(displayIndex)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.teal.opacity(0.4))
                    .frame(width: 32, alignment: .leading)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.teal.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: "book.pages")
                        .font(.title2)
                        .foregroundColor(.teal)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.name)
                        .font(.headline)
                    Text("\(lesson.pages?.count ?? 0) Pages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .foregroundColor(.secondary.opacity(0.3))
            }
            
            Divider()
            
            HStack(spacing: 12) {
                Button("Manage Pages") { onEdit() }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                
                Spacer()
                
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(20)
        .background(Color.platformSystemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}
