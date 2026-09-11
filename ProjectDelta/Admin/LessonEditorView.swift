//
//  LessonEditorView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseFirestore
import Observation

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

struct LessonEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var lessonTitle: String
    @State private var pages: [Page] = []
    @State private var lessonTests: [Test] = []
    
    var lesson: Lesson
    var subject: Subject
    var onSave: (() -> Void)? = nil
    
    let primaryTeal = Color(red: 0.12, green: 0.65, blue: 0.65)
    let glowingPurple = Color(red: 0.6, green: 0.2, blue: 0.9)
    let vibrantOrange = Color.orange
    
    init(lesson: Lesson = Lesson(id: nil, name: "", description: "", completed: false, lessonNumber: 1, pages: nil), subject: Subject, onSave: (() -> Void)? = nil) {
        self.lesson = lesson
        self.subject = subject
        self.onSave = onSave
        _lessonTitle = State(initialValue: lesson.name)
        
        var initialPages = lesson.pages ?? []
        if initialPages.isEmpty && !lesson.description.isEmpty {
            initialPages.append(Page(id: UUID().uuidString, content: lesson.description, pageNumber: 1, readyButtonDisplayed: true))
        }
        _pages = State(initialValue: initialPages)
    }

    var body: some View {
        ZStack {
            Color.platformSystemGroupedBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Premium Glass Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lesson.id?.isEmpty == false ? "Edit Lesson" : "Author New Lesson")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [.primary, primaryTeal], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text("Construct your educational material across multiple pages.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // Metadata Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ZStack {
                                Circle().fill(primaryTeal.opacity(0.15)).frame(width: 32, height: 32)
                                Image(systemName: "text.book.closed.fill").foregroundColor(primaryTeal).font(.system(size: 14, weight: .bold))
                            }
                            Text("Lesson Metadata")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        
                        Divider()
                        
                        TextField("Enter Lesson Title...", text: $lessonTitle)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .padding(14)
                            .background(Color.platformSecondarySystemBackground)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                            .onChange(of: lessonTitle) { _, _ in fetchTests() }
                        
                        HStack {
                            Text("Parent Subject")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(subject.name)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(primaryTeal)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(primaryTeal.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.04), radius: 15, y: 8)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                    .padding(.horizontal, 24)
                    
                    // Pages Manager
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ZStack {
                                Circle().fill(glowingPurple.opacity(0.15)).frame(width: 32, height: 32)
                                Image(systemName: "square.stack.3d.down.right.fill").foregroundColor(glowingPurple).font(.system(size: 14, weight: .bold))
                            }
                            Text("Lesson Pages")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            
                            Spacer()
                            
                            Button(action: addNewPage) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(primaryTeal)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                        
                        if pages.isEmpty {
                            ContentUnavailableView("No Pages", systemImage: "doc.text", description: Text("Add a page to start building your lesson content."))
                                .padding(.vertical, 32)
                                .background(Color.platformSystemBackground)
                                .cornerRadius(20)
                                .padding(.horizontal, 24)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach($pages.indices, id: \.self) { index in
                                    NavigationLink(destination: PageEditorView(page: $pages[index], pageIndex: index + 1)) {
                                        PageAdminCard(page: pages[index], displayIndex: index + 1) {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                pages.remove(at: index)
                                                recalculatePageNumbers()
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 24)
                                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                                }
                            }
                        }
                    }
                    
                    // Assessments Manager
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ZStack {
                                Circle().fill(vibrantOrange.opacity(0.15)).frame(width: 32, height: 32)
                                Image(systemName: "bolt.badge.automatic.fill").foregroundColor(vibrantOrange).font(.system(size: 14, weight: .bold))
                            }
                            Text("Lesson Assessments")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            
                            Spacer()
                            
                            NavigationLink(destination: AddTestView(subject: subject, lessonName: lessonTitle, existingTest: nil)) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(vibrantOrange)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                        
                        if lessonTests.isEmpty {
                            ContentUnavailableView("No Assessments", systemImage: "doc.questionmark", description: Text("Create an assessment to link practice material to this lesson."))
                                .padding(.vertical, 32)
                                .background(Color.platformSystemBackground)
                                .cornerRadius(20)
                                .padding(.horizontal, 24)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(lessonTests.enumerated()), id: \.element.id) { index, test in
                                    NavigationLink(destination: AddTestView(subject: subject, lessonName: lessonTitle, existingTest: test)) {
                                        TestAdminCard(test: test, displayIndex: index + 1) {
                                            deleteTest(test)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 24)
                                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 160) // Extra padding for safe scrolling past sticky buttons
                }
            }
            #if os(macOS)
            .safeAreaPadding(.top, 56)
            #endif
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            fetchTests()
        }
        .toolbar {
            #if os(macOS)
            ToolbarItem(placement: .confirmationAction) {
                Button("Save Curriculum") { saveLesson() }
                    .fontWeight(.bold)
                    .buttonStyle(.borderedProminent)
                    .tint(primaryTeal)
                    .disabled(lessonTitle.isEmpty)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.secondary)
            }
            #endif
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                #if os(iOS)
                Button(action: saveLesson) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Save Curriculum")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(primaryTeal.gradient)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: primaryTeal.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(lessonTitle.isEmpty)
                #endif
                
                NavigationLink(destination: AddTestView(subject: subject, lessonName: lessonTitle, existingTest: nil)) {
                    HStack {
                        Image(systemName: "bolt.badge.automatic.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Create New Assessment")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(vibrantOrange.gradient)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: vibrantOrange.opacity(0.4), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            #if os(iOS)
            .padding(.bottom, 90) // Forces clearance over custom tab bar
            #else
            .padding(.bottom, 24)
            #endif
            .padding(.top, 12)
            .background(.ultraThinMaterial)
        }
    }
    
    // MARK: - Local Test Retrieval & Deletion
    
    private func fetchTests() {
        guard let subjectId = subject.id, !lessonTitle.isEmpty else { return }
        Task {
            do {
                let db = Firestore.firestore()
                let snapshot = try await db.collection("Subjects").document(subjectId)
                    .collection("Tests")
                    .whereField("subtopic", isEqualTo: lessonTitle)
                    .getDocuments()
                
                let fetched = snapshot.documents.compactMap { try? $0.data(as: Test.self) }
                await MainActor.run {
                    self.lessonTests = fetched.sorted { ($0.title ?? "") < ($1.title ?? "") }
                }
            } catch {
                print("Failed to fetch tests: \(error)")
            }
        }
    }

    private func deleteTest(_ test: Test) {
        guard let subjectId = subject.id, let testId = test.id else { return }
        Task {
            do {
                let db = Firestore.firestore()
                let batch = db.batch()
                let testRef = db.collection("Subjects").document(subjectId).collection("Tests").document(testId)
                
                let qSnap = try await testRef.collection("Questions").getDocuments()
                for doc in qSnap.documents {
                    batch.deleteDocument(doc.reference)
                    batch.deleteDocument(db.collection("questions").document(doc.documentID))
                }
                
                batch.deleteDocument(testRef)
                try await batch.commit()
                
                await MainActor.run {
                    withAnimation {
                        lessonTests.removeAll { $0.id == testId }
                    }
                }
            } catch {
                print("Failed to delete test architecture: \(error)")
            }
        }
    }
    
    // MARK: - Lesson Page Operations
    
    private func addNewPage() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            let newPage = Page(id: UUID().uuidString, content: "[]", pageNumber: pages.count + 1, readyButtonDisplayed: true)
            pages.append(newPage)
        }
    }
    
    private func recalculatePageNumbers() {
        for i in 0..<pages.count {
            pages[i].pageNumber = i + 1
        }
    }
    
    private func saveLesson() {
        Task {
            let db = Firestore.firestore()
            guard let subjectId = subject.id, !subjectId.isEmpty else { return }
            
            recalculatePageNumbers()
            
            let mappedPages = pages.map { page -> [String: Any] in
                return [
                    "id": page.id ?? UUID().uuidString,
                    "content": page.content,
                    "pageNumber": page.pageNumber,
                    "readyButtonDisplayed": page.readyButtonDisplayed
                ]
            }
            
            var lessonData: [String: Any] = [
                "name": lessonTitle,
                "subject": subject.name,
                "description": pages.first?.content ?? "",
                "pages": mappedPages,
                "completed": lesson.completed,
                "lessonNumber": lesson.lessonNumber,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            do {
                if let existingId = lesson.id, !existingId.isEmpty {
                    try await db.collection("Subjects").document(subjectId).collection("Lessons").document(existingId).setData(lessonData, merge: true)
                } else {
                    let newDocRef = db.collection("Subjects").document(subjectId).collection("Lessons").document()
                    lessonData["id"] = newDocRef.documentID
                    try await newDocRef.setData(lessonData)
                }
                
                await MainActor.run {
                    onSave?()
                    dismiss()
                }
            } catch {
                print("Failed to save lesson architecture: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Test Admin Card
struct TestAdminCard: View {
    let test: Test
    let displayIndex: Int
    let onDelete: () -> Void
    @State private var isHovered = false
    
    let vibrantOrange = Color.orange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("\(displayIndex)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(vibrantOrange.opacity(0.3))
                    .frame(width: 28, alignment: .leading)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(vibrantOrange.gradient.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "checklist")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(vibrantOrange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(test.title ?? "Assessment")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Linked Assessment")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
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
        }
        .padding(16)
        .background(Color.platformSystemBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(isHovered ? 0.08 : 0.04), radius: isHovered ? 12 : 8, y: isHovered ? 6 : 4)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Page Admin Card
struct PageAdminCard: View {
    let page: Page
    let displayIndex: Int
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("\(displayIndex)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(red: 0.6, green: 0.2, blue: 0.9).opacity(0.3))
                    .frame(width: 28, alignment: .leading)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.6, green: 0.2, blue: 0.9).gradient.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(red: 0.6, green: 0.2, blue: 0.9))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Page \(displayIndex)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(page.readyButtonDisplayed ? "Ready Button Enabled" : "Read-Only Mode")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
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
        }
        .padding(16)
        .background(Color.platformSystemBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(isHovered ? 0.08 : 0.04), radius: isHovered ? 12 : 8, y: isHovered ? 6 : 4)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.05), lineWidth: 1))
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Page Editor View
struct PageEditorView: View {
    @Binding var page: Page
    let pageIndex: Int
    @State private var blocks: [QuestionBlockModel] = []
    @State private var autoSaveTask: Task<Void, Never>?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.platformSystemGroupedBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                UniversalBlockEditorView(blocks: $blocks, onSave: {
                    saveBlocksToPage()
                    dismiss()
                })
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            #if os(iOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
            #if os(macOS)
            .safeAreaPadding(.top, 56)
            #endif
        }
        .navigationTitle("Page \(pageIndex) Editor")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onTapGesture {
            #if os(iOS)
            hideKeyboard()
            #endif
        }
        .onAppear { loadBlocks() }
        .onChange(of: blocks) { _, _ in queueAutoSave() }
        .onDisappear {
            autoSaveTask?.cancel()
            if let data = try? JSONEncoder().encode(blocks),
               let jsonString = String(data: data, encoding: .utf8) {
                page.content = jsonString
            }
        }
    }

    private func loadBlocks() {
        let textData = page.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textData.isEmpty else { return }
        
        if let data = textData.data(using: .utf8) {
            if let decoded = try? JSONDecoder().decode([QuestionBlockModel].self, from: data) {
                blocks = decoded
                return
            }
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                blocks = jsonArray.compactMap { dict in
                    let type = dict["type"] as? String ?? QuestionBlockType.text.rawValue
                    let content = dict["content"] as? String ?? ""
                    let graphType = dict["graphType"] as? String
                    return QuestionBlockModel(type: type, content: content, graphType: graphType)
                }
                return
            }
        }
        blocks = parseLegacyContentToBlocks(textData)
    }

    private func parseLegacyContentToBlocks(_ content: String) -> [QuestionBlockModel] {
        var parsedBlocks: [QuestionBlockModel] = []
        var remaining = content

        while !remaining.isEmpty {
            let mathRange = remaining.range(of: "[MATH]")
            let graphRange = remaining.range(of: "[GRAPH]")

            var nextTagRange: Range<String.Index>?
            var isMath = false

            if let m = mathRange, let g = graphRange {
                if m.lowerBound < g.lowerBound {
                    nextTagRange = m
                    isMath = true
                } else {
                    nextTagRange = g
                    isMath = false
                }
            } else if let m = mathRange {
                nextTagRange = m
                isMath = true
            } else if let g = graphRange {
                nextTagRange = g
                isMath = false
            }

            guard let startTag = nextTagRange else {
                let text = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    parsedBlocks.append(QuestionBlockModel(type: QuestionBlockType.text.rawValue, content: text))
                }
                break
            }

            let textBefore = String(remaining[..<startTag.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !textBefore.isEmpty {
                parsedBlocks.append(QuestionBlockModel(type: QuestionBlockType.text.rawValue, content: textBefore))
            }

            remaining = String(remaining[startTag.upperBound...])
            let endTagStr = isMath ? "[/MATH]" : "[/GRAPH]"

            if let endTagRange = remaining.range(of: endTagStr) {
                let innerContent = String(remaining[..<endTagRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if isMath {
                    parsedBlocks.append(QuestionBlockModel(type: QuestionBlockType.math.rawValue, content: innerContent))
                } else {
                    let gType = innerContent.contains("type=points") ? "points" : "equation"
                    var gContent = innerContent
                    if let eqRange = gContent.range(of: "equation=") {
                        gContent = String(gContent[eqRange.upperBound...])
                    } else if let ptRange = gContent.range(of: "points=") {
                        gContent = String(gContent[ptRange.upperBound...])
                    }
                    parsedBlocks.append(QuestionBlockModel(type: QuestionBlockType.graph.rawValue, content: gContent, graphType: gType))
                }
                remaining = String(remaining[endTagRange.upperBound...])
            } else {
                parsedBlocks.append(QuestionBlockModel(type: QuestionBlockType.text.rawValue, content: remaining))
                break
            }
        }
        return parsedBlocks.isEmpty ? [QuestionBlockModel(type: QuestionBlockType.text.rawValue, content: content)] : parsedBlocks
    }

    private func saveBlocksToPage() {
        if let data = try? JSONEncoder().encode(blocks),
           let jsonString = String(data: data, encoding: .utf8) {
            page.content = jsonString
        } else {
            page.content = blocks.map { $0.content }.joined(separator: "\n")
        }
    }

    private func queueAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            
            let snapshot = blocks
            let jsonString: String? = await Task.detached(priority: .utility) {
                guard let data = try? JSONEncoder().encode(snapshot) else { return nil }
                return String(data: data, encoding: .utf8)
            }.value
            
            await MainActor.run {
                if let json = jsonString {
                    self.page.content = json
                } else {
                    self.page.content = snapshot.map { $0.content }.joined(separator: "\n")
                }
            }
        }
    }
}
