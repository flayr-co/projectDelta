//
//  LessonEditorView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseFirestore
import Observation

struct LessonEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var lessonTitle: String
    @State private var showTestBuilder: Bool = false
    @State private var pages: [Page] = []
    
    var lesson: Lesson
    var subject: Subject
    
    init(lesson: Lesson = Lesson(id: nil, name: "", description: "", completed: false, lessonNumber: 1, pages: nil), subject: Subject) {
        self.lesson = lesson
        self.subject = subject
        _lessonTitle = State(initialValue: lesson.name)
        
        // Initialize pages; if legacy lesson only has a description, migrate it to page 1
        var initialPages = lesson.pages ?? []
        if initialPages.isEmpty && !lesson.description.isEmpty {
            initialPages.append(Page(id: UUID().uuidString, content: lesson.description, pageNumber: 1, readyButtonDisplayed: true))
        }
        _pages = State(initialValue: initialPages)
    }

    var body: some View {
        // NavigationStack strictly removed to prevent safe-area intersection bugs when pushed
        ZStack {
            Color.platformSystemGroupedBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lesson.id?.isEmpty == false ? "Edit Lesson" : "Author New Lesson")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                        Text("Construct your educational material across multiple pages.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    // Metadata Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "text.book.closed.fill")
                                .foregroundColor(.teal)
                            Text("Lesson Metadata")
                                .font(.headline)
                        }
                        
                        Divider()
                        
                        TextField("Enter Lesson Title...", text: $lessonTitle)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(16)
                            .background(Color.platformSecondarySystemBackground)
                            .cornerRadius(12)
                        
                        HStack {
                            Text("Parent Subject")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                            Spacer()
                            Text(subject.name)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.teal.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                    .padding(24)
                    .background(Color.platformSystemBackground)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                    .padding(.horizontal, 24)
                    
                    // Pages Manager
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "square.stack.3d.down.right.fill")
                                .foregroundColor(.purple)
                            Text("Lesson Pages")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: addNewPage) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.teal)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                        
                        if pages.isEmpty {
                            ContentUnavailableView("No Pages", systemImage: "doc.text", description: Text("Add a page to start building your lesson content."))
                                .padding(.vertical, 32)
                        } else {
                            ForEach($pages.indices, id: \.self) { index in
                                NavigationLink(destination: PageEditorView(page: $pages[index], pageIndex: index + 1)) {
                                    PageAdminCard(page: pages[index], displayIndex: index + 1) {
                                        pages.remove(at: index)
                                        recalculatePageNumbers()
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 24)
                            }
                        }
                    }
                    
                    Spacer(minLength: 120)
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
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save Curriculum") { saveLesson() }
                    .fontWeight(.bold)
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .disabled(lessonTitle.isEmpty)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.secondary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: { showTestBuilder = true }) {
                HStack {
                    Image(systemName: "wand.and.stars.inverse")
                        .font(.title3)
                    Text("Generate Linked Test")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(14)
                .shadow(color: Color.purple.opacity(0.3), radius: 10, y: 5)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .background(Color.platformSystemGroupedBackground.opacity(0.95))
        }
        .sheet(isPresented: $showTestBuilder) {
            NavigationStack {
                AddTestView(subject: subject, lessonName: lessonTitle)
            }
        }
    }
    
    private func addNewPage() {
        withAnimation(.spring) {
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
                "description": pages.first?.content ?? "", // Legacy support fallback
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
                dismiss()
            } catch {
                print("Failed to save lesson architecture: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Page Admin Card
struct PageAdminCard: View {
    let page: Page
    let displayIndex: Int
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Text("\(displayIndex)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.purple.opacity(0.4))
                    .frame(width: 32, alignment: .leading)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Page \(displayIndex)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(page.readyButtonDisplayed ? "Ready Button Enabled" : "Read-Only Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .padding(10)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(20)
        .background(Color.platformSystemBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Page Editor View
struct PageEditorView: View {
    @Binding var page: Page
    let pageIndex: Int
    @State private var blocks: [QuestionBlockModel] = []
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.platformSystemGroupedBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                UniversalBlockEditorView(blocks: $blocks, onSave: {
                    saveBlocksToPage()
                    dismiss()
                })
                .padding(24)
            }
            #if os(macOS)
            .safeAreaPadding(.top, 56)
            #endif
        }
        .navigationTitle("Page \(pageIndex) Editor")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { loadBlocks() }
        .onChange(of: blocks) { _, _ in saveBlocksToPage() }
    }

    private func loadBlocks() {
        let textData = page.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textData.isEmpty else { return }
        
        if let data = textData.data(using: .utf8) {
            // Attempt primary strict codable decode
            if let decoded = try? JSONDecoder().decode([QuestionBlockModel].self, from: data) {
                blocks = decoded
                return
            }
            // Fault-tolerant fallback: Parses legacy database JSON missing 'id' tags
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
        
        // Final fallback: Parse legacy [MATH] and [GRAPH] tags into proper split QuestionBlockModels
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
}
