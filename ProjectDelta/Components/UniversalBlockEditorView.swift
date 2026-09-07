//
//  UniversalBlockEditorView.swift
//  ProjectDelta
//

import SwiftUI

struct UniversalBlockEditorView: View {
    @Binding var blocks: [QuestionBlockModel]
    var onSave: (() -> Void)? = nil
    
    @State private var isSaved: Bool = false
    @State private var showingBulkImporter: Bool = false
    @State private var bulkImportText: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // MARK: Floating Save Header
            HStack {
                Spacer()
                Button(action: {
                    #if os(iOS)
                    hideKeyboard()
                    #endif
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isSaved = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        onSave?()
                        isSaved = false
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isSaved ? "checkmark.seal.fill" : "square.and.arrow.down.fill")
                        Text(isSaved ? "Page Saved" : "Save Page")
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(isSaved ? Color.green.gradient : Color.teal.gradient)
                    .clipShape(Capsule())
                    .shadow(color: (isSaved ? Color.green : Color.teal).opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.success, trigger: isSaved)
            }
            .padding(.bottom, 8)
            
            // MARK: Block Cells
            ForEach($blocks) { $block in
                let blockId = block.id
                
                BlockEditCell(block: $block) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        blocks.removeAll { $0.id == blockId }
                    }
                }
                .transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity))
            }
            
            // MARK: Premium Glass Add Menu
            VStack(spacing: 16) {
                Text("Add Content")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                HStack(spacing: 12) {
                    AddBlockButton(title: "Text", icon: "text.alignleft", color: .blue) { addBlock(type: .text) }
                    AddBlockButton(title: "Math", icon: "x.squareroot", color: .teal) { addBlock(type: .math) }
                    AddBlockButton(title: "Graph", icon: "chart.xyaxis.line", color: .purple) { addBlock(type: .graph) }
                }
                
                Button(action: { showingBulkImporter = true }) {
                    HStack {
                        Image(systemName: "doc.on.clipboard.fill")
                        Text("Bulk Import Lesson")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .onTapGesture {
            #if os(iOS)
            hideKeyboard()
            #endif
        }
        .sheet(isPresented: $showingBulkImporter) {
            NavigationStack {
                VStack {
                    TextEditor(text: $bulkImportText)
                        .font(.system(.body, design: .monospaced))
                        .padding(12)
                        .background(Color.platformSecondarySystemBackground)
                        .cornerRadius(12)
                        .padding()
                }
                .navigationTitle("Bulk Importer")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingBulkImporter = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") { processBulkImport() }
                            .fontWeight(.bold)
                            .tint(.orange)
                    }
                }
                .background(Color.platformSystemGroupedBackground.ignoresSafeArea())
            }
        }
    }
    
    private func addBlock(type: QuestionBlockType) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            blocks.append(QuestionBlockModel(type: type.rawValue, content: ""))
        }
    }
    
    private func processBulkImport() {
        var remaining = bulkImportText
        var newBlocks: [QuestionBlockModel] = []
        let tags = ["TEXT", "MATH", "GRAPH"]
        
        while !remaining.isEmpty {
            var earliestTag: String? = nil
            var earliestIndex: String.Index? = nil
            
            for tag in tags {
                if let range = remaining.range(of: "[\(tag)]") {
                    if earliestIndex == nil || range.lowerBound < earliestIndex! {
                        earliestIndex = range.lowerBound
                        earliestTag = tag
                    }
                }
            }
            
            guard let startTag = earliestTag, let startIndex = earliestIndex else { break }
            let endTagStr = "[/\(startTag)]"
            
            let contentStart = remaining.range(of: "[\(startTag)]")!.upperBound
            remaining = String(remaining[contentStart...])
            
            if let endRange = remaining.range(of: endTagStr) {
                let content = String(remaining[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                var block = QuestionBlockModel(
                    type: startTag == "TEXT" ? QuestionBlockType.text.rawValue : (startTag == "MATH" ? QuestionBlockType.math.rawValue : QuestionBlockType.graph.rawValue),
                    content: content
                )
                
                remaining = String(remaining[endRange.upperBound...])
                
                if startTag == "MATH" {
                    let nextText = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
                    if nextText.hasPrefix("[CAPTION]") {
                        if let captionEndRange = remaining.range(of: "[/CAPTION]") {
                            let capStart = remaining.range(of: "[CAPTION]")!.upperBound
                            let caption = String(remaining[capStart..<captionEndRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                            block.caption = caption
                            remaining = String(remaining[captionEndRange.upperBound...])
                        }
                    }
                }
                newBlocks.append(block)
            } else {
                break
            }
        }
        
        if !newBlocks.isEmpty {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                blocks.append(contentsOf: newBlocks)
            }
            bulkImportText = ""
            showingBulkImporter = false
        }
    }
}

// MARK: - Premium Add Block Button
fileprivate struct AddBlockButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.bold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modern Block Cell
fileprivate struct BlockEditCell: View {
    @Binding var block: QuestionBlockModel
    var onDelete: () -> Void
    
    @State private var isEditing: Bool
    @FocusState private var isFocused: Bool
    @State private var selectedRange = NSRange(location: 0, length: 0)
    
    // Custom Math Prompt States
    enum MathPromptType { case fraction, exponent, root, highlight }
    @State private var showMathPrompt = false
    @State private var mathPromptType: MathPromptType = .fraction
    @State private var mathArg1: String = ""
    @State private var mathArg2: String = ""
    
    init(block: Binding<QuestionBlockModel>, onDelete: @escaping () -> Void) {
        self._block = block
        self.onDelete = onDelete
        self._isEditing = State(initialValue: block.wrappedValue.content.isEmpty)
    }
    
    private func applyFormatting(prefix: String, suffix: String) {
        if selectedRange.length > 0, let range = Range(selectedRange, in: block.content) {
            let selectedText = String(block.content[range])
            let formattedText = "\(prefix)\(selectedText)\(suffix)"
            block.content.replaceSubrange(range, with: formattedText)
        } else {
            block.content.append("\(prefix)\(suffix)")
        }
        selectedRange = NSRange(location: 0, length: 0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: iconForType())
                    .font(.title3)
                    .foregroundColor(colorForType())
                    .frame(width: 36, height: 36)
                    .background(colorForType().opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.type.capitalized)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: isEditing ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.title3)
                    .foregroundColor(isEditing ? colorForType() : .secondary.opacity(0.3))
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isEditing.toggle()
                    if isEditing { isFocused = true }
                }
            }

            if isEditing {
                Divider()
                
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        
                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                                .padding(10)
                                .background(Color.red.opacity(0.15))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            #if os(iOS)
                            hideKeyboard()
                            #endif
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isEditing = false
                                isFocused = false
                            }
                        }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.green.gradient)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if block.type == QuestionBlockType.text.rawValue {
                        buildTextEditor()
                    } else if block.type == QuestionBlockType.math.rawValue {
                        buildMathEditor()
                    } else if block.type == QuestionBlockType.graph.rawValue {
                        buildGraphEditor()
                    }
                }
                .padding(20)
                .background(Color.platformSystemBackground)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(isEditing ? 0.08 : 0.04), radius: isEditing ? 15 : 8, y: isEditing ? 6 : 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isEditing ? colorForType().opacity(0.5) : Color.gray.opacity(0.15), lineWidth: 1)
        )
        .padding(.vertical, 4)
        .onAppear {
            if isEditing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
    }

    private var summaryText: String {
        let trimmed = block.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Empty \(block.type.lowercased()) block" }
        return trimmed
    }
    
    @ViewBuilder
    private func buildTextEditor() -> some View {
        SelectableTextEditor(text: $block.content, selectedRange: $selectedRange, isMonospaced: false)
            .frame(minHeight: 100)
            .padding(12)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            .focused($isFocused)
            .overlay(
                Group {
                    if block.content.isEmpty {
                        Text("Enter instructional prose or context...")
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.leading, 16)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }, alignment: .topLeading
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? colorForType() : Color.clear, lineWidth: 2)
            )
            .toolbar {
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    if isFocused && block.type == QuestionBlockType.text.rawValue {
                        HStack(spacing: 8) {
                            EditorToolbarButton(display: "B") { applyFormatting(prefix: "**", suffix: "**") }
                            EditorToolbarButton(display: "I") { applyFormatting(prefix: "*", suffix: "*") }
                        }
                        Spacer()
                        Button("Done") { isFocused = false }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
                #endif
            }
    }
    
    @ViewBuilder
    private func buildMathEditor() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LaTeX Expression")
                .font(.caption)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .foregroundColor(.secondary)
            
            SelectableTextEditor(text: $block.content, selectedRange: $selectedRange, isMonospaced: true)
                .frame(minHeight: 80)
                .padding(12)
                .background(Color.teal.opacity(0.05))
                .cornerRadius(12)
                .focused($isFocused)
                .overlay(
                    Group {
                        if block.content.isEmpty {
                            Text("e.g. \\frac{1}{2}x + 5")
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary.opacity(0.6))
                                .padding(.leading, 16)
                                .padding(.top, 16)
                                .allowsHitTesting(false)
                        }
                    }, alignment: .topLeading
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.teal : Color.clear, lineWidth: 2)
                )
                .toolbar {
                    #if os(iOS)
                    ToolbarItemGroup(placement: .keyboard) {
                        if isFocused && block.type == QuestionBlockType.math.rawValue {
                            mathKeyboardToolbar()
                        }
                    }
                    #endif
                }

            TextField("Optional Footnote Caption...", text: Binding(
                get: { block.caption ?? "" },
                set: { block.caption = $0.isEmpty ? nil : $0 }
            ))
            .font(.system(size: 14))
            .padding(12)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
            
            #if os(macOS)
            if isFocused {
                MathKeypadView(
                    text: $block.content,
                    onHighlight: { applyFormatting(prefix: "*blue ", suffix: " blue*") }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            #endif
        }
        .alert(promptTitle, isPresented: $showMathPrompt) {
            mathPromptActions()
        } message: {
            Text(promptMessage)
        }
    }
    
    #if os(iOS)
    @ViewBuilder
    private func mathKeyboardToolbar() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Group {
                    EditorToolbarButton(display: "+") { block.content.append("+") }
                    EditorToolbarButton(display: "-") { block.content.append("-") }
                    EditorToolbarButton(display: "=") { block.content.append("=") }
                    EditorToolbarButton(display: "(") { block.content.append("(") }
                    EditorToolbarButton(display: ")") { block.content.append(")") }
                    EditorToolbarButton(display: "<") { block.content.append("<") }
                    EditorToolbarButton(display: ">") { block.content.append(">") }
                    EditorToolbarButton(display: "a/b") {
                        mathPromptType = .fraction; mathArg1 = ""; mathArg2 = ""; showMathPrompt = true
                    }
                    EditorToolbarButton(display: "x²") { block.content.append("^{2}") }
                    EditorToolbarButton(display: "xⁿ") {
                        mathPromptType = .exponent; mathArg1 = ""; mathArg2 = ""; showMathPrompt = true
                    }
                }
                
                Group {
                    EditorToolbarButton(display: "√") {
                        mathPromptType = .root; mathArg1 = ""; mathArg2 = ""; showMathPrompt = true
                    }
                    EditorToolbarButton(display: "÷") { block.content.append("\\div") }
                    EditorToolbarButton(display: "×") { block.content.append("\\times") }
                    EditorToolbarButton(display: "sin") { block.content.append("\\sin()") }
                    EditorToolbarButton(display: "cos") { block.content.append("\\cos()") }
                    EditorToolbarButton(display: "tan") { block.content.append("\\tan()") }
                    EditorToolbarButton(display: "ln") { block.content.append("\\ln()") }
                    EditorToolbarButton(display: "π") { block.content.append("\\pi") }
                    EditorToolbarButton(display: "θ") { block.content.append("\\theta") }
                    EditorToolbarButton(display: "∞") { block.content.append("\\infty") }
                }
                
                Group {
                    EditorToolbarButton(display: "HL") {
                        mathPromptType = .highlight; mathArg1 = ""; showMathPrompt = true
                    }
                    EditorToolbarButton(display: "∫") { block.content.append("\\int") }
                    EditorToolbarButton(display: "°") { block.content.append("^{\\circ}") }
                }
            }
            .padding(.horizontal, 4)
        }
        
        Button("Done") { isFocused = false }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.teal)
            .clipShape(Capsule())
    }
    #endif

    @ViewBuilder
    private func mathPromptActions() -> some View {
        TextField(promptPlaceholder1, text: $mathArg1)
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
        
        if mathPromptType == .fraction {
            TextField("Denominator (e.g. 2 or x)", text: $mathArg2)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
        }
        
        Button("Cancel", role: .cancel) { }
        
        if mathPromptType == .highlight {
            Button("Blue") { block.content.append("*blue \(mathArg1) blue*") }
            Button("Red") { block.content.append("*red \(mathArg1) red*") }
            Button("Green") { block.content.append("*green \(mathArg1) green*") }
        } else {
            Button("Insert") {
                switch mathPromptType {
                case .fraction:
                    block.content.append("\\frac{\(mathArg1)}{\(mathArg2)}")
                case .exponent:
                    block.content.append("^{\(mathArg1)}")
                case .root:
                    block.content.append("\\sqrt{\(mathArg1)}")
                default: break
                }
            }
        }
    }
    
    private var promptTitle: String {
        switch mathPromptType {
        case .fraction: return "Insert Fraction"
        case .exponent: return "Insert Exponent"
        case .root: return "Insert Square Root"
        case .highlight: return "Highlight Text"
        }
    }
    
    private var promptPlaceholder1: String {
        switch mathPromptType {
        case .fraction: return "Numerator (e.g. 1)"
        case .exponent: return "Exponent (e.g. 2x)"
        case .root: return "Value (e.g. x+5)"
        case .highlight: return "Text to highlight"
        }
    }
    
    private var promptMessage: String {
        switch mathPromptType {
        case .fraction: return "Enter the numerator and denominator values."
        case .exponent: return "Enter the exponent value. It will be added to the end of the current expression."
        case .root: return "Enter the value inside the square root."
        case .highlight: return "Enter the text or equation you want to highlight."
        }
    }
    
    @ViewBuilder
    private func buildGraphEditor() -> some View {
        let selectedGraphType = block.graphType ?? QuestionGraphType.equation.rawValue
        let expressions = block.content.isEmpty ? [""] : block.content.components(separatedBy: "\n")
        
        VStack(alignment: .leading, spacing: 18) {
            Picker("Graph Mode", selection: Binding(
                get: { selectedGraphType },
                set: { block.graphType = $0 }
            )) {
                Text("Equations").tag(QuestionGraphType.equation.rawValue)
                Text("Points").tag(QuestionGraphType.points.rawValue)
            }
            .pickerStyle(.segmented)
            
            if isEditing {
                InteractiveGraphBuilderView(
                    content: $block.content,
                    graphType: selectedGraphType
                )
                .frame(height: 360)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Expressions")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                ForEach(0..<max(1, expressions.count), id: \.self) { index in
                    HStack {
                        TextField(selectedGraphType == QuestionGraphType.equation.rawValue ? "y = x^2 + 3" : "(0, 0), (2, 3)", text: Binding(
                            get: {
                                guard index < expressions.count else { return "" }
                                return expressions[index]
                            },
                            set: { newValue in
                                var newExpressions = expressions
                                if index < newExpressions.count {
                                    newExpressions[index] = newValue
                                } else {
                                    newExpressions.append(newValue)
                                }
                                block.content = newExpressions.joined(separator: "\n")
                            }
                        ))
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .padding(14)
                        .background(Color.purple.opacity(0.06))
                        .cornerRadius(12)
                        .focused($isFocused)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            isFocused = false
                        }
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        
                        if expressions.count > 1 {
                            Button(action: {
                                var newExpressions = expressions
                                newExpressions.remove(at: index)
                                block.content = newExpressions.joined(separator: "\n")
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Button(action: {
                    var newExpressions = expressions
                    newExpressions.append("")
                    block.content = newExpressions.joined(separator: "\n")
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Expression")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.purple)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .toolbar {
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    if isFocused && block.type == QuestionBlockType.graph.rawValue {
                        Spacer()
                        Button("Done") { isFocused = false }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.purple)
                            .clipShape(Capsule())
                    }
                }
                #endif
            }
        }
    }
    
    private func iconForType() -> String {
        switch block.type {
        case QuestionBlockType.text.rawValue: return "text.alignleft"
        case QuestionBlockType.math.rawValue: return "function"
        case QuestionBlockType.graph.rawValue: return "chart.xyaxis.line"
        default: return "cube"
        }
    }
    
    private func colorForType() -> Color {
        switch block.type {
        case QuestionBlockType.text.rawValue: return .blue
        case QuestionBlockType.math.rawValue: return .teal
        case QuestionBlockType.graph.rawValue: return .purple
        default: return .primary
        }
    }
}

// MARK: - Live Block Rendering Engine
struct LiveBlockRenderView: View {
    let block: QuestionBlockModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if block.type == QuestionBlockType.text.rawValue {
            let parsed = parseEditorContent(block.content)
            
            if parsed.isEmpty {
                Text("Empty Text Block")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(parsed, id: \EditorParsedContentBlock.id) { pBlock in
                        render(pBlock: pBlock)
                    }
                }
            }
        } else if block.type == QuestionBlockType.math.rawValue {
            VStack(alignment: .leading, spacing: 8) {
                if block.content.isEmpty {
                    Text("Empty Math Block")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(colorScheme == .dark ? Color.black.opacity(0.4) : Color.gray.opacity(0.1))
                        .cornerRadius(12)
                } else {
                    LatexView(latex: "$$ " + block.content.parsedMathToLatex + " $$")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(colorScheme == .dark ? Color.black.opacity(0.4) : Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                if let caption = block.caption, !caption.isEmpty {
                    Text(LocalizedStringKey(caption.parsedInlineMathToMarkdown))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
            }
        } else if block.type == QuestionBlockType.graph.rawValue {
            let parsedData = GraphContentParser.graphData(from: block.content, graphType: block.graphType)
            DynamicGraphView(data: parsedData)
                .frame(height: 320)
                .background(Color.platformSecondarySystemBackground)
                .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private func render(pBlock: EditorParsedContentBlock) -> some View {
        switch pBlock.type {
        case .text(let text):
            if text.contains("$") {
                LatexView(latex: text.parsedMathToLatex, isTextMode: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(LocalizedStringKey(text.parsedInlineMathToMarkdown))
                    .font(.system(size: 21, weight: .regular, design: .serif))
                    .lineSpacing(12)
                    .foregroundColor(.primary.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .math(let latex):
            LatexView(latex: "$$ \(latex) $$")
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(colorScheme == .dark ? Color.black.opacity(0.4) : Color.gray.opacity(0.1))
                .cornerRadius(16)
        case .graph(let graphStr):
            InlineGraphRenderer(graphString: graphStr, themeColor: colorScheme == .dark ? .teal : .blue)
        }
    }
}

// MARK: - Editor Text Parsing Engine
struct EditorParsedContentBlock: Identifiable {
    let id = UUID()
    let type: BlockType

    enum BlockType {
        case text(String)
        case math(String)
        case graph(String)
    }
}

func parseEditorContent(_ content: String) -> [EditorParsedContentBlock] {
    var blocks: [EditorParsedContentBlock] = []
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
                blocks.append(EditorParsedContentBlock(type: .text(text)))
            }
            break
        }

        let textBefore = String(remaining[..<startTag.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !textBefore.isEmpty {
            blocks.append(EditorParsedContentBlock(type: .text(textBefore)))
        }

        remaining = String(remaining[startTag.upperBound...])
        let endTagStr = isMath ? "[/MATH]" : "[/GRAPH]"

        if let endTagRange = remaining.range(of: endTagStr) {
            let innerContent = String(remaining[..<endTagRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if isMath {
                blocks.append(EditorParsedContentBlock(type: .math(innerContent)))
            } else {
                blocks.append(EditorParsedContentBlock(type: .graph(innerContent)))
            }
            remaining = String(remaining[endTagRange.upperBound...])
        } else {
            blocks.append(EditorParsedContentBlock(type: .text(remaining)))
            break
        }
    }
    return blocks
}
