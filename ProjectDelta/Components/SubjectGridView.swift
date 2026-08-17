//
//  SubjectGridView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseFirestore

enum NavigationSource {
    case learn
    case quickTest
    case timedExam
    case practice
}

// Helper struct to organize the curriculum
struct CurriculumSection: Hashable {
    let title: String
    let subjects: [String]
}

struct SubjectGridView: View {
    @Environment(TestSessionViewModel.self) var testViewModel
    @Environment(LessonViewModel.self) var lessonVM

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    var navigationSource: NavigationSource
    
    let warmTan = Color(red: 0.97, green: 0.96, blue: 0.94)
    
    // Dynamically categorize the string-based subjects into a proper curriculum
    private var curriculumSections: [CurriculumSection] {
        var algebra: [String] = []
        var advanced: [String] = []
        var data: [String] = []
        var geometry: [String] = []
        var other: [String] = []
        
        for subject in testViewModel.subjects {
            let lower = subject.lowercased()
            if lower.contains("algebra") && !lower.contains("linear") && !lower.contains("abstract") {
                algebra.append(subject)
            } else if lower.contains("calc") || lower.contains("linear") || lower.contains("matrix") || lower.contains("diff") || lower.contains("advanced") || lower.contains("aero") {
                advanced.append(subject)
            } else if lower.contains("data") || lower.contains("stat") || lower.contains("prob") {
                data.append(subject)
            } else if lower.contains("geometry") || lower.contains("trig") || lower.contains("precalc") {
                geometry.append(subject)
            } else {
                other.append(subject)
            }
        }
        
        var sections: [CurriculumSection] = []
        if !algebra.isEmpty { sections.append(CurriculumSection(title: "Algebra & Foundations", subjects: algebra)) }
        if !geometry.isEmpty { sections.append(CurriculumSection(title: "Geometry & Trigonometry", subjects: geometry)) }
        if !advanced.isEmpty { sections.append(CurriculumSection(title: "Advanced Mathematics", subjects: advanced)) }
        if !data.isEmpty { sections.append(CurriculumSection(title: "Problem Solving & Data", subjects: data)) }
        if !other.isEmpty { sections.append(CurriculumSection(title: "Additional Topics", subjects: other)) }
        
        // Sort sections dynamically based on their highest-ranked subject from the Admin panel
        sections.sort { sectionA, sectionB in
            let minIndexA = sectionA.subjects.compactMap { testViewModel.subjects.firstIndex(of: $0) }.min() ?? Int.max
            let minIndexB = sectionB.subjects.compactMap { testViewModel.subjects.firstIndex(of: $0) }.min() ?? Int.max
            return minIndexA < minIndexB
        }
        
        return sections
    }
    
    var body: some View {
        Group {
            #if os(macOS)
            macOSLayout
            #else
            iOSLayout
            #endif
        }
        .navigationBarBackButtonHidden(true)
        #if os(macOS)
        .toolbarVisibility(.hidden, for: .windowToolbar)
        #endif
        .task {
            do {
                // Fetch directly to ensure sorting by admin-defined 'order' field rather than alphabetical.
                let snapshot = try await Firestore.firestore().collection("Subjects")
                    .order(by: "orderIndex")
                    .getDocuments()
                
                let fetchedSubjects = snapshot.documents.compactMap { $0.data()["name"] as? String }
                
                if !fetchedSubjects.isEmpty {
                    testViewModel.subjects = fetchedSubjects
                } else {
                    // Fallback to view model method if custom fetch yields nothing
                    testViewModel.subjects = try await testViewModel.fetchSubjectsFromFirestore()
                }
            } catch {
                print("Error fetching ordered subjects in SubjectGridView: \(error.localizedDescription)")
                do {
                    // Final fallback
                    testViewModel.subjects = try await testViewModel.fetchSubjectsFromFirestore()
                } catch {
                    print("Fallback fetch failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - DESKTOP LAYOUT (macOS)
    #if os(macOS)
    private var macOSLayout: some View {
        ZStack {
            Color.platformSystemGroupedBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                macOSHeaderView
                
                // Grid Content Scroll
                ScrollView(showsIndicators: false) {
                    let desktopColumns = [
                        GridItem(.adaptive(minimum: 320, maximum: 400), spacing: 24)
                    ]
                    
                    VStack(alignment: .leading, spacing: 48) {
                        ForEach(curriculumSections, id: \.title) { section in
                            VStack(alignment: .leading, spacing: 20) {
                                Text(section.title)
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundColor(.primary.opacity(0.8))
                                
                                LazyVGrid(columns: desktopColumns, spacing: 24) {
                                    ForEach(section.subjects, id: \.self) { subject in
                                        NavigationLink {
                                            destinationView(for: subject)
                                        } label: {
                                            // Derive the sequence number from the globally sorted array
                                            let globalIndex = (testViewModel.subjects.firstIndex(of: subject) ?? 0) + 1
                                            subjectCard(for: subject, index: globalIndex)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 40)
                    .frame(maxWidth: 1200)
                }
            }
        }
    }
    
    private var macOSHeaderView: some View {
        HStack(spacing: 24) {
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                    Text("Back")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Text("Curriculum Pathways")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.top, 40) // Explicitly buffers against macOS system controls
        .padding(.bottom, 20)
        .background(Color.platformSystemBackground)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(Color.primary.opacity(0.05)),
            alignment: .bottom
        )
    }
    #endif // os(macOS)

    // MARK: - MOBILE LAYOUT (iOS)
    #if os(iOS)
    private var iOSLayout: some View {
        ZStack {
            (colorScheme == .dark ? Color(red: 0.10, green: 0.10, blue: 0.12) : warmTan)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    BackButtonView {
                        dismiss()
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Dashboard Title Block
                VStack(alignment: .leading, spacing: 6) {
                    Text("Table of Contents")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.5)
                    
                    Text("Select a Pathway")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                // Content Scroll - Converted to Vertical List for full text fitting
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        ForEach(curriculumSections, id: \.title) { section in
                            VStack(alignment: .leading, spacing: 16) {
                                Text(section.title)
                                    .font(.title3)
                                    .fontWeight(.black)
                                    .foregroundColor(.primary.opacity(0.8))
                                    .padding(.horizontal, 24)
                                
                                LazyVStack(spacing: 16) {
                                    ForEach(section.subjects, id: \.self) { subject in
                                        NavigationLink {
                                            destinationView(for: subject)
                                        } label: {
                                            // Properly derive global index instead of local index
                                            let globalIndex = (testViewModel.subjects.firstIndex(of: subject) ?? 0) + 1
                                            subjectCard(for: subject, index: globalIndex)
                                        }
                                        .buttonStyle(SubjectCardButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 120) // Ensure the bottom content is not obscured
                }
            }
        }
    }
    #endif // os(iOS)
    
    @ViewBuilder
    private func destinationView(for subject: String) -> some View {
        switch navigationSource {
        case .learn:
            LessonSelectionView(subjectName: subject, navigationSource: .learn)
                .environment(lessonVM)
                .environment(testViewModel)
        case .quickTest:
            UniversalTestView(mode: .quick(subject: subject, subtopic: nil))
                .environment(testViewModel)
        case .timedExam:
            UniversalTestView(mode: .timed(subject: subject, subtopic: nil))
                .environment(testViewModel)
        case .practice:
            LessonSelectionView(subjectName: subject, navigationSource: .practice)
                .environment(testViewModel)
                .environment(lessonVM)
        }
    }
    
    @ViewBuilder
    private func subjectCard(for subject: String, index: Int) -> some View {
        let theme = themeForSubject(subject)
        
        HStack(spacing: 20) {
            // Sequence Number Identifier
            Text(String(format: "%02d", index))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(theme.opacity(colorScheme == .dark ? 0.3 : 0.25))
                .frame(width: 40, alignment: .leading)
            
            // Styled Icon Context
            ZStack {
                Circle()
                    .fill(theme.opacity(colorScheme == .dark ? 0.15 : 0.1))
                    .frame(width: 52, height: 52)
                
                Image(systemName: iconForSubject(subject))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(theme)
            }
            
            // Title Text
            Text(subject)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
            
            // Nav Indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.secondary.opacity(0.3))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                #if os(macOS)
                .fill(Color.platformSystemBackground)
                #else
                .fill(colorScheme == .dark ? Color(red: 0.14, green: 0.14, blue: 0.16) : .white)
                #endif
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.opacity(0.2), lineWidth: 1.5)
        )
        .shadow(color: theme.opacity(colorScheme == .dark ? 0.1 : 0.05), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Dynamic Theming Functions
    private func themeForSubject(_ subject: String) -> Color {
        let lower = subject.lowercased()
        if lower.contains("algebra") { return .blue }
        if lower.contains("calculus") { return .orange }
        if lower.contains("geometry") { return .purple }
        if lower.contains("trig") { return .indigo }
        if lower.contains("data") || lower.contains("stat") || lower.contains("prob") { return .pink }
        if lower.contains("physics") || lower.contains("aero") { return .red }
        if lower.contains("linear") || lower.contains("matrix") { return .teal }
        if lower.contains("advanced") { return .cyan }
        return .green
    }
    
    private func iconForSubject(_ subject: String) -> String {
        let lower = subject.lowercased()
        if lower.contains("algebra") { return "function" }
        if lower.contains("calculus") { return "chart.xyaxis.line" }
        if lower.contains("geometry") { return "triangle" }
        if lower.contains("physics") || lower.contains("aero") { return "rocket.tilt.fill" }
        if lower.contains("linear") || lower.contains("matrix") { return "line.3.horizontal.circle" }
        if lower.contains("data") || lower.contains("stat") { return "chart.bar.fill" }
        return "book.closed.fill"
    }
}

// MARK: - Lesson Selection View (For Practice Mode)

struct LessonSelectionView: View {
    var subjectName: String
    var navigationSource: NavigationSource = .practice
    
    @Environment(TestSessionViewModel.self) var testViewModel
    @Environment(LessonViewModel.self) var lessonVM
    @Environment(AuthViewModel.self) var authVM
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @State private var lessons: [(id: String, name: String)] = []
    @State private var isLoading = true
    
    let warmTan = Color(red: 0.97, green: 0.96, blue: 0.94)
    
    private var themeColor: Color {
        let lower = subjectName.lowercased()
        if lower.contains("algebra") { return .blue }
        if lower.contains("calculus") { return .orange }
        if lower.contains("geometry") { return .purple }
        if lower.contains("trig") { return .indigo }
        if lower.contains("data") || lower.contains("stat") || lower.contains("prob") { return .pink }
        if lower.contains("physics") || lower.contains("aero") { return .red }
        if lower.contains("linear") || lower.contains("matrix") { return .teal }
        if lower.contains("advanced") { return .cyan }
        return .green
    }
    
    var body: some View {
        Group {
            #if os(macOS)
            macOSLayout
            #else
            iOSLayout
            #endif
        }
        .navigationBarBackButtonHidden(true)
        #if os(macOS)
        .toolbarVisibility(.hidden, for: .windowToolbar)
        #endif
        .task {
            await fetchLessonsWithTests()
        }
    }
    
    // MARK: - DESKTOP LAYOUT (macOS)
    #if os(macOS)
    private var macOSLayout: some View {
        ZStack {
            Color.platformSystemGroupedBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                macOSHeaderView
                
                if isLoading {
                    Spacer()
                    ProgressView("Loading curriculum material...")
                        .tint(themeColor)
                    Spacer()
                } else if lessons.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Content Available",
                        systemImage: "book.closed.fill",
                        description: Text("There are currently no lessons sequenced for this subject.")
                    )
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        let desktopColumns = [
                            GridItem(.adaptive(minimum: 320, maximum: 400), spacing: 24)
                        ]
                        
                        LazyVGrid(columns: desktopColumns, spacing: 24) {
                            ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                                NavigationLink(destination: destinationForLesson(lesson)) {
                                    lessonCard(for: lesson.name, index: index + 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 40)
                        .frame(maxWidth: 1200)
                    }
                }
            }
        }
    }
    
    private var macOSHeaderView: some View {
        HStack(spacing: 24) {
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                    Text("Back")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Text("\(subjectName) Curriculum")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.top, 40) // Explicitly buffers against macOS system controls
        .padding(.bottom, 20)
        .background(Color.platformSystemBackground)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(Color.primary.opacity(0.05)),
            alignment: .bottom
        )
    }
    #endif // os(macOS)

    // MARK: - MOBILE LAYOUT (iOS)
    #if os(iOS)
    private var iOSLayout: some View {
        ZStack {
            (colorScheme == .dark ? Color(red: 0.10, green: 0.10, blue: 0.12) : warmTan)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    BackButtonView { dismiss() }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(subjectName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(1.5)
                    
                    Text("Curriculum Path")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                if isLoading {
                    Spacer()
                    ProgressView("Loading curriculum material...")
                        .tint(themeColor)
                    Spacer()
                } else if lessons.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Content Available",
                        systemImage: "book.closed.fill",
                        description: Text("There are currently no lessons sequenced for this subject.")
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                                NavigationLink {
                                    destinationForLesson(lesson)
                                } label: {
                                    lessonCard(for: lesson.name, index: index + 1)
                                }
                                .buttonStyle(SubjectCardButtonStyle())
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 120) // Navigation elements protection
                    }
                }
            }
        }
    }
    #endif // os(iOS)
    
    private func fetchLessonsWithTests() async {
        isLoading = true
        do {
            let db = Firestore.firestore()
            let subjectQuery = try await db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments()
            
            // Store the lessonNumber alongside the ID and name
            var lessonTuples: [(id: String, name: String, order: Int)] = []
            
            if let subjectId = subjectQuery.documents.first?.documentID {
                let lessonsSnap = try await db.collection("Subjects").document(subjectId).collection("Lessons").getDocuments()
                for doc in lessonsSnap.documents {
                    if let name = doc.data()["name"] as? String {
                        let order = doc.data()["lessonNumber"] as? Int ?? Int.max
                        lessonTuples.append((id: doc.documentID, name: name, order: order))
                    }
                }
            }
            
            var uniqueLessons: [(id: String, name: String, order: Int)] = []
            var seenNames = Set<String>()
            
            for tuple in lessonTuples {
                if !seenNames.contains(tuple.name) {
                    seenNames.insert(tuple.name)
                    uniqueLessons.append(tuple)
                }
            }
            
            // Sort by the sequential integer rather than alphabetically
            let sortedTuples = uniqueLessons.sorted { $0.order < $1.order }
            self.lessons = sortedTuples.map { (id: $0.id, name: $0.name) }
        } catch {
            print("Error parsing practice lessons: \(error)")
        }
        isLoading = false
    }
    
    @ViewBuilder
    private func destinationForLesson(_ lesson: (id: String, name: String)) -> some View {
        if navigationSource == .learn {
            LessonView(subjectName: subjectName, initialLessonName: lesson.name)
        } else {
            UniversalTestView(mode: .practice(subject: subjectName, lessonName: lesson.name, lessonId: lesson.id))
                .environment(testViewModel)
        }
    }
    
    @ViewBuilder
    private func lessonCard(for lessonName: String, index: Int) -> some View {
        HStack(spacing: 20) {
            // Sequence Number Identifier
            Text(String(format: "%02d", index))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(themeColor.opacity(colorScheme == .dark ? 0.3 : 0.25))
                .frame(width: 40, alignment: .leading)
            
            // Styled Icon Context
            ZStack {
                Circle()
                    .fill(themeColor.opacity(colorScheme == .dark ? 0.15 : 0.1))
                    .frame(width: 52, height: 52)
                
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(themeColor)
            }
            
            // Title Text
            Text(lessonName)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
            
            // Nav Indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.secondary.opacity(0.3))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                #if os(macOS)
                .fill(Color.platformSystemBackground)
                #else
                .fill(colorScheme == .dark ? Color(red: 0.14, green: 0.14, blue: 0.16) : .white)
                #endif
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(themeColor.opacity(0.2), lineWidth: 1.5)
        )
        #if os(macOS)
        .shadow(color: themeColor.opacity(0.05), radius: 10, x: 0, y: 5)
        #else
        .shadow(color: themeColor.opacity(colorScheme == .dark ? 0.1 : 0.05), radius: 10, x: 0, y: 5)
        #endif
    }
}

struct SubjectCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
