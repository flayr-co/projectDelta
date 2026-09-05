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
    
    @State private var showingAddSubjectAlert = false
    @State private var newSubjectName = ""
    
    // UI Constants
    private let primaryTeal = Color(red: 0.12, green: 0.65, blue: 0.65)
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.platformSystemGroupedBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Premium Glass Header
                    ZStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Curriculum Architect")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(LinearGradient(colors: [.primary, primaryTeal], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Text("Manage your subject hierarchy, lessons, and assessment database.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        #if os(macOS)
                        .frame(maxWidth: 800) // Aligns perfectly with the grid below
                        #endif
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    #if os(macOS)
                    .padding(.top, 44) // Generous clearance for macOS window controls
                    #else
                    .padding(.top, 20)
                    #endif
                    .padding(.bottom, 20)
                    .background(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                    .zIndex(10)
                    
                    // Interactive Fluid Grid
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 24) {
                            ForEach(Array(viewModel.subjects.enumerated()), id: \.element.id) { index, subject in
                                SubjectAdminCard(subject: subject, displayIndex: index + 1, viewModel: viewModel, onEdit: {
                                    selectedSubject = subject
                                })
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                            }
                        }
                        .padding(32)
                        .padding(.bottom, 60)
                        #if os(macOS)
                        .frame(maxWidth: 800) // Constrains width on Mac for premium layout
                        .frame(maxWidth: .infinity, alignment: .center)
                        #endif
                    }
                    .scrollDismissesKeyboard(.interactively)
                    // Hoisted navigation destination resolves all console warnings
                    .navigationDestination(item: $selectedSubject) { subject in
                        LessonManagerView(subject: subject, viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { showingAddSubjectAlert = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(primaryTeal)
                            .padding(8)
                            .background(primaryTeal.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
            .alert("Add New Subject", isPresented: $showingAddSubjectAlert) {
                TextField("Subject Name (e.g. Calculus 1)", text: $newSubjectName)
                Button("Cancel", role: .cancel) {
                    newSubjectName = ""
                }
                Button("Create") {
                    let cleanName = newSubjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanName.isEmpty else { return }
                    Task {
                        await viewModel.addSubject(name: cleanName)
                        newSubjectName = ""
                    }
                }
            } message: {
                Text("Enter the title for your new curriculum sequence.")
            }
            .overlay {
                if viewModel.isProcessing {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Syncing Database...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
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
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                // Sequence Indicator
                Text("\(displayIndex)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.teal.opacity(0.3))
                    .frame(width: 36, alignment: .leading)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.teal.gradient.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: subject.imageName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.teal)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("\(subject.lessonCount) Lessons")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.4))
            }
            
            Divider()
            
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit Curriculum")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.teal)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button(role: .destructive, action: { Task { await viewModel.deleteSubject(id: subject.id ?? "") } }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 44, height: 44)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(Color.platformSystemBackground)
        .cornerRadius(24)
        .shadow(color: .black.opacity(isHovered ? 0.08 : 0.04), radius: isHovered ? 12 : 8, y: isHovered ? 6 : 4)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Lesson Manager
struct LessonManagerView: View {
    let subject: Subject
    @Bindable var viewModel: AdminViewModel
    @State private var showingAddLesson = false
    @State private var selectedLesson: Lesson?
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.platformSystemGroupedBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(Array(viewModel.lessons.enumerated()), id: \.element.id) { index, lesson in
                            LessonAdminCard(lesson: lesson, displayIndex: index + 1, onEdit: {
                                selectedLesson = lesson
                            }, onDelete: {
                                Task { await viewModel.deleteLesson(subjectId: subject.id ?? "", lessonId: lesson.id ?? "") }
                            })
                        }
                    }
                    .padding(32)
                    #if os(macOS)
                    .frame(maxWidth: 800)
                    .frame(maxWidth: .infinity, alignment: .center)
                    #endif
                }
                .navigationDestination(item: $selectedLesson) { lesson in
                    LessonEditorView(lesson: lesson, subject: subject)
                }
            }
        }
        .navigationTitle(subject.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await viewModel.fetchLessons(for: subject.id ?? "") }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddLesson = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("New Lesson")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.teal.opacity(0.15))
                    .foregroundColor(.teal)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingAddLesson) {
            NavigationStack {
                LessonEditorView(
                    lesson: Lesson(id: nil, name: "", description: "", completed: false, lessonNumber: viewModel.lessons.count + 1, pages: nil),
                    subject: subject
                )
            }
        }
        .onChange(of: showingAddLesson) { _, isShowing in
            if !isShowing {
                Task { await viewModel.fetchLessons(for: subject.id ?? "") }
            }
        }
        .onChange(of: selectedLesson) { _, lesson in
            if lesson == nil {
                Task { await viewModel.fetchLessons(for: subject.id ?? "") }
            }
        }
    }
}

// MARK: - Refined Lesson Card
struct LessonAdminCard: View {
    let lesson: Lesson
    let displayIndex: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Text("\(displayIndex)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(.teal.opacity(0.4))
                    .frame(width: 32, alignment: .leading)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.teal.gradient.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: "book.pages.fill")
                        .font(.title2)
                        .foregroundColor(.teal)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("\(lesson.pages?.count ?? 0) Pages")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            Button(action: onEdit) {
                HStack {
                    Text("Manage Pages")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 14, weight: .bold))
                .padding(16)
                .background(Color.teal.opacity(0.08))
                .foregroundColor(.teal)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(Color.platformSystemBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(isHovered ? 0.06 : 0.03), radius: isHovered ? 12 : 8, y: isHovered ? 6 : 4)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
