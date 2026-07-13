//
//  AdminView.swift
//  ProjectDelta
//

import SwiftUI
import Observation

struct AdminView: View {
    @State private var viewModel = AdminViewModel()
    @Environment(\.dismiss) var dismiss
    
    // UI Constants
    private let primaryTeal = Color(red: 0.12, green: 0.65, blue: 0.65)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Curriculum Architect")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                        Text("Manage your subject hierarchy, lessons, and assessment database.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 48) // Clears the macOS sidebar toggle
                    
                    // Subject Grid
                    ForEach(viewModel.subjects) { subject in
                        SubjectAdminCard(subject: subject, viewModel: viewModel)
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .background(Color.platformSystemGroupedBackground.ignoresSafeArea())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { /* Add Global Subject Logic */ }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(primaryTeal)
                    }
                }
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
    @Bindable var viewModel: AdminViewModel
    @State private var showingLessons = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
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
                    Text("\(subject.subtopics.count) Lessons")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Divider()
            
            HStack(spacing: 12) {
                Button("Edit Curriculum") { showingLessons = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                
                Button(role: .destructive, action: { Task { await viewModel.deleteSubject(id: subject.id ?? "") } }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(Color.platformSystemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        .navigationDestination(isPresented: $showingLessons) {
            LessonManagerView(subject: subject, viewModel: viewModel)
        }
    }
}

// MARK: - Lesson Manager
struct LessonManagerView: View {
    let subject: Subject
    @Bindable var viewModel: AdminViewModel
    @State private var showingEditor = false
    
    var body: some View {
        List {
            Section("Lesson Inventory") {
                ForEach(viewModel.lessons) { lesson in
                    NavigationLink(destination: LessonEditorView(lesson: lesson, subject: subject)) {
                        VStack(alignment: .leading) {
                            Text(lesson.name).font(.headline)
                            Text("Page Count: \(lesson.pages?.count ?? 0)").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(subject.name)
        .task { await viewModel.fetchLessons(for: subject.id ?? "") }
        .toolbar {
            Button("New Lesson") { showingEditor = true }
        }
        .sheet(isPresented: $showingEditor) {
            LessonEditorView(subject: subject)
        }
    }
}
