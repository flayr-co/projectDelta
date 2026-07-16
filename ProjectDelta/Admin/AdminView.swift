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
                .padding(.top, 32)
                .padding(.bottom, 16)
                
                // Interactive List Grid
                List {
                    ForEach(viewModel.subjects) { subject in
                        SubjectAdminCard(subject: subject, viewModel: viewModel)
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
            }
            .background(Color.platformSystemGroupedBackground)
            // Ensures macOS window controls do not collide with the custom header
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
    @Bindable var viewModel: AdminViewModel
    @State private var showingLessons = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                // Sequence Indicator
                Text("\(subject.orderIndex + 1)")
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
                Button("Edit Curriculum") { showingLessons = true }
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
            Section("Lesson Sequence") {
                ForEach(viewModel.lessons) { lesson in
                    NavigationLink(destination: LessonEditorView(lesson: lesson, subject: subject)) {
                        HStack(spacing: 16) {
                            // Sequence Indicator
                            Text("\(lesson.lessonNumber)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.teal.opacity(0.6))
                                .frame(width: 24, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(lesson.name)
                                    .font(.headline)
                                Text("Page Count: \(lesson.pages?.count ?? 0)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onMove { source, destination in
                    viewModel.updateLessonOrder(subjectId: subject.id ?? "", from: source, to: destination)
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle(subject.name)
        .task { await viewModel.fetchLessons(for: subject.id ?? "") }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Lesson") { showingEditor = true }
            }
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            #endif
        }
        .sheet(isPresented: $showingEditor) {
            LessonEditorView(subject: subject)
        }
    }
}
