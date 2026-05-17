//
//  LessonEditorView.swift
//  ProjectDelta
//

import SwiftUI
import Observation

enum ContentBlockType: String, CaseIterable {
    case text = "Text"
    case math = "Equation"
    case graph = "Graph"
}

enum GraphInputType: String, CaseIterable {
    case equation = "Function (y = f(x))"
    case points = "Coordinate Points"
}

struct GraphPoint: Identifiable, Equatable {
    let id = UUID()
    var x: Double
    var y: Double
}

@Observable
class DraftBlock: Identifiable {
    let id = UUID()
    var type: ContentBlockType
    
    // Text & Math State
    var textContent: String = ""
    
    // Graph State
    var graphInputType: GraphInputType = .equation
    var graphEquation: String = ""
    var graphPoints: [GraphPoint] = [GraphPoint(x: 0, y: 0)]
    
    init(type: ContentBlockType) {
        self.type = type
    }
}

struct LessonEditorView: View {
    @Bindable var viewModel: AdminViewModel
    var subject: Subject
    var lesson: Lesson?
    
    @Environment(\.dismiss) var dismiss
    
    @State private var lessonName: String = ""
    @State private var lessonDescription: String = ""
    @State private var lessonNumber: Int = 1
    @State private var minLessonNumber: Int = 1
    @State private var pages: [Page] = []
    
    // Visual Builder State
    @State private var draftBlocks: [DraftBlock] = []
    @FocusState private var focusedBlockId: UUID?
    @State private var debouncedLatex: [UUID: String] = [:]
    
    // Preview State
    @State private var showPreview: Bool = false
    
    var body: some View {
        Form {
            Section("Lesson Configuration") {
                TextField("Lesson Title", text: $lessonName)
                    .font(.headline)
                TextField("Short Description", text: $lessonDescription)
                Stepper("Lesson Number: \(lessonNumber)", value: $lessonNumber, in: minLessonNumber...1000)
            }
            
            Section("Compiled Pages") {
                if pages.isEmpty {
                    Text("No pages have been finalized yet. Build a page below and commit it to see it here.")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                } else {
                    ForEach(pages.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Page \(pages[index].pageNumber)")
                                .font(.headline)
                                .foregroundColor(.teal)
                            Text(pages[index].content)
                                .lineLimit(3)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        pages.remove(atOffsets: indexSet)
                        for i in 0..<pages.count {
                            pages[i].pageNumber = i + 1
                        }
                    }
                }
            }
            
            Section("Active Page Builder") {
                // Draft Blocks
                ForEach(draftBlocks) { block in
                    @Bindable var bindableBlock = block
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(block.type.rawValue, systemImage: icon(for: block.type))
                                .font(.headline)
                                .foregroundColor(color(for: block.type))
                            
                            Spacer()
                            
                            Button(role: .destructive) {
                                withAnimation {
                                    draftBlocks.removeAll { $0.id == block.id }
                                }
                            } label: {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless) // Strict bounding to prevent misfiring
                        }
                        
                        switch block.type {
                        case .text:
                            TextEditor(text: $bindableBlock.textContent)
                                .focused($focusedBlockId, equals: block.id)
                                .frame(minHeight: 120)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                            
                        case .math:
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Enter plain text math. Exponents use (), multiplication uses *.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("e.g., (x+1)/(2x) or e^(8x)", text: $bindableBlock.textContent)
                                    .focused($focusedBlockId, equals: block.id)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numbersAndPunctuation)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .onChange(of: bindableBlock.textContent) { oldValue, newValue in
                                        Task {
                                            try? await Task.sleep(nanoseconds: 500_000_000)
                                            if bindableBlock.textContent == newValue {
                                                await MainActor.run {
                                                    debouncedLatex[block.id] = newValue
                                                }
                                            }
                                        }
                                    }
                                
                                let previewText = debouncedLatex[block.id] ?? ""
                                if !previewText.isEmpty {
                                    Text("Will render as:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    LatexView(latex: "$$" + parseToLatex(previewText) + "$$")
                                        .frame(minHeight: 70)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(8)
                                }
                            }
                            
                        case .graph:
                            VStack(alignment: .leading, spacing: 12) {
                                Picker("Graph Type", selection: $bindableBlock.graphInputType) {
                                    ForEach(GraphInputType.allCases, id: \.self) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(.segmented)
                                
                                if bindableBlock.graphInputType == .equation {
                                    TextField("Enter function (e.g., y = x^2 + 2x)", text: $bindableBlock.graphEquation)
                                        .focused($focusedBlockId, equals: block.id)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.numbersAndPunctuation)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                } else {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach($bindableBlock.graphPoints) { $point in
                                            HStack {
                                                Text("X:")
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                                TextField("0.0", value: $point.x, format: .number)
                                                    .textFieldStyle(.roundedBorder)
                                                    .keyboardType(.decimalPad)
                                                
                                                Text("Y:")
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                                TextField("0.0", value: $point.y, format: .number)
                                                    .textFieldStyle(.roundedBorder)
                                                    .keyboardType(.decimalPad)
                                                
                                                if bindableBlock.graphPoints.count > 1 {
                                                    Button(role: .destructive) {
                                                        withAnimation {
                                                            bindableBlock.graphPoints.removeAll { $0.id == point.id }
                                                        }
                                                    } label: {
                                                        Image(systemName: "minus.circle.fill")
                                                            .font(.title2)
                                                    }
                                                    .buttonStyle(.borderless)
                                                }
                                            }
                                        }
                                        
                                        Button {
                                            withAnimation {
                                                bindableBlock.graphPoints.append(GraphPoint(x: 0, y: 0))
                                            }
                                        } label: {
                                            Label("Add Coordinate", systemImage: "plus.circle.fill")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                        }
                                        .buttonStyle(.borderless)
                                        .padding(.top, 4)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(color(for: block.type).opacity(0.05))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(color(for: block.type).opacity(0.3), lineWidth: 1))
                    .padding(.vertical, 4)
                }
                
                // Explicit Action Buttons for Block Addition
                VStack(spacing: 12) {
                    Text("Add components to current page:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 12) {
                        BlockTypeButton(title: "Text", icon: "text.alignleft", color: .primary) {
                            addBlock(of: .text)
                        }
                        
                        BlockTypeButton(title: "Equation", icon: "function", color: .blue) {
                            addBlock(of: .math)
                        }
                        
                        BlockTypeButton(title: "Graph", icon: "chart.xyaxis.line", color: .green) {
                            addBlock(of: .graph)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                Button(action: commitPage) {
                    Text("Compile Blocks & Save Page")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(isDraftEmpty())
                .padding(.top, 8)
            }
            
            Section {
                Button(action: {
                    Task {
                        let newLesson = Lesson(
                            id: lesson?.id,
                            name: lessonName,
                            description: lessonDescription,
                            completed: false,
                            lessonNumber: lessonNumber,
                            pages: pages
                        )
                        try? await viewModel.addLesson(to: subject, lesson: newLesson)
                        dismiss()
                    }
                }) {
                    Text("Publish Lesson to Database")
                        .font(.title3)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
            }
        }
        .navigationTitle(lesson == nil ? "New Lesson" : "Edit Lesson")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPreview = true
                } label: {
                    HStack {
                        Image(systemName: "eye")
                        Text("Preview")
                    }
                }
                // Previews should be available if there is drafted UI OR finalized pages
                .disabled(isDraftEmpty() && pages.isEmpty)
            }
        }
        .sheet(isPresented: $showPreview) {
            PagePreviewSheet(draftBlocks: draftBlocks)
        }
        .onAppear {
            if let l = lesson {
                // Editing an existing lesson
                lessonName = l.name
                lessonDescription = l.description
                lessonNumber = l.lessonNumber
                minLessonNumber = 1 // Unlocks constraints so previous lessons can be adjusted
                pages = l.pages ?? []
            } else {
                // Creating a new lesson
                let maxLessonNumber = viewModel.lessons.map { $0.lessonNumber }.max() ?? 0
                let nextAvailable = maxLessonNumber + 1
                lessonNumber = nextAvailable
                minLessonNumber = nextAvailable // Enforces that the teacher cannot decrement below the next available slot
            }
        }
    }
    
    // MARK: - Builder Helpers
    
    private func addBlock(of type: ContentBlockType) {
        withAnimation {
            let newBlock = DraftBlock(type: type)
            draftBlocks.append(newBlock)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedBlockId = newBlock.id
            }
        }
    }
    
    private func isDraftEmpty() -> Bool {
        if draftBlocks.isEmpty { return true }
        
        return draftBlocks.allSatisfy { block in
            switch block.type {
            case .text, .math:
                return block.textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .graph:
                if block.graphInputType == .equation {
                    return block.graphEquation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                } else {
                    return block.graphPoints.isEmpty
                }
            }
        }
    }
    
    private func icon(for type: ContentBlockType) -> String {
        switch type {
        case .text: return "text.alignleft"
        case .math: return "function"
        case .graph: return "chart.xyaxis.line"
        }
    }
    
    private func color(for type: ContentBlockType) -> Color {
        switch type {
        case .text: return .primary
        case .math: return .blue
        case .graph: return .green
        }
    }
    
    private func commitPage() {
        var finalContent = ""
        
        for block in draftBlocks {
            switch block.type {
            case .text:
                let trimmed = block.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    finalContent += "\(trimmed)\n\n"
                }
                
            case .math:
                let trimmed = block.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let latex = parseToLatex(trimmed)
                    finalContent += "[MATH]\n\(latex)\n[/MATH]\n\n"
                }
                
            case .graph:
                if block.graphInputType == .equation {
                    let trimmed = block.graphEquation.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        finalContent += "[GRAPH]\ntype=equation|equation=\(trimmed)\n[/GRAPH]\n\n"
                    }
                } else {
                    if !block.graphPoints.isEmpty {
                        let pointString = block.graphPoints.map { "\($0.x),\($0.y)" }.joined(separator: ";")
                        finalContent += "[GRAPH]\ntype=points|points=\(pointString)\n[/GRAPH]\n\n"
                    }
                }
            }
        }
        
        let cleanedContent = finalContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedContent.isEmpty else { return }
        
        let newPage = Page(
            content: cleanedContent,
            pageNumber: pages.count + 1,
            readyButtonDisplayed: false
        )
        
        withAnimation {
            pages.append(newPage)
            draftBlocks.removeAll()
        }
    }
}

// MARK: - Parsing Engine

private func parseToLatex(_ input: String) -> String {
    var result = input
    
    // Converts e^(8x) to e^{8x}
    result = result.replacingOccurrences(of: "\\^\\(([^)]+)\\)", with: "^{$1}", options: .regularExpression)
    
    // Converts (x+1)/(2x) to \frac{x+1}{2x}
    result = result.replacingOccurrences(of: "\\(([^)]+)\\)/\\(([^)]+)\\)", with: "\\\\frac{$1}{$2}", options: .regularExpression)
    
    // Converts isolated numerator fractions like x/(2x) to \frac{x}{2x}
    result = result.replacingOccurrences(of: "([a-zA-Z0-9]+)/\\(([^)]+)\\)", with: "\\\\frac{$1}{$2}", options: .regularExpression)
    
    // Converts standard multiplication * to LaTeX \cdot
    result = result.replacingOccurrences(of: "\\*", with: "\\\\cdot ")
    
    return result
}

// MARK: - Subviews

struct BlockTypeButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.borderless) // STRICT FIX: Isolates tap gesture inside Forms
    }
}

struct PagePreviewSheet: View {
    var draftBlocks: [DraftBlock]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(draftBlocks) { block in
                        switch block.type {
                        case .text:
                            Text(block.textContent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        case .math:
                            LatexView(latex: "$$" + parseToLatex(block.textContent) + "$$")
                                .frame(minHeight: 50)
                        case .graph:
                            Text("[Graph Preview Placeholder: \(block.graphInputType == .equation ? block.graphEquation : "Coordinate Data")]")
                                .italic()
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Page Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
