//
//  UniversalBlockEditorView.swift
//  ProjectDelta
//

import SwiftUI

struct UniversalBlockEditorView: View {
    @Binding var blocks: [QuestionBlockModel]
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach($blocks) { $block in
                BlockEditCell(block: $block) {
                    withAnimation {
                        blocks.removeAll { $0.id == block.id }
                    }
                }
            }
            
            Menu {
                Button(action: { addBlock(type: .text) }) {
                    Label("Add Plain Text", systemImage: "text.alignleft")
                }
                Button(action: { addBlock(type: .math) }) {
                    Label("Add Math Equation", systemImage: "x.squareroot")
                }
                Button(action: { addBlock(type: .graph) }) {
                    Label("Add Graph", systemImage: "chart.xyaxis.line")
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Content Block")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(12)
            }
        }
    }
    
    private func addBlock(type: QuestionBlockType) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            blocks.append(QuestionBlockModel(type: type.rawValue, content: ""))
        }
    }
}

fileprivate struct BlockEditCell: View {
    @Binding var block: QuestionBlockModel
    var onDelete: () -> Void
    
    @FocusState private var isMathFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(block.type, systemImage: iconForType())
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(colorForType())
                
                Spacer()
                
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            if block.type == QuestionBlockType.text.rawValue {
                TextField("Enter plain text instruction or context...", text: $block.content, axis: .vertical)
                    .lineLimit(3...10)
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    
            } else if block.type == QuestionBlockType.math.rawValue {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Use the keypad below to build simple expressions.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Equation or math expression...", text: $block.content, axis: .vertical)
                        .lineLimit(2...6)
                        .font(.system(.body, design: .monospaced))
                        .padding(10)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .focused($isMathFocused)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                if isMathFocused {
                                    Spacer()
                                    Button("Done") {
                                        isMathFocused = false
                                    }
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                    
                    if isMathFocused {
                        MathKeypadView(text: $block.content)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .padding(.top, 4)
                    }
                }
            } else if block.type == QuestionBlockType.graph.rawValue {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Graph Type", selection: Binding(
                        get: { block.graphType ?? QuestionGraphType.equation.rawValue },
                        set: { block.graphType = $0 }
                    )) {
                        ForEach(QuestionGraphType.allCases, id: \.rawValue) { type in
                            Text(type.rawValue).tag(type.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    let placeholder = block.graphType == QuestionGraphType.equation.rawValue ? "Enter function (e.g., y = 2x + 1)" : "Enter coordinates (e.g., (1,2), (3,4))"
                    
                    TextField(placeholder, text: $block.content, axis: .vertical)
                        .lineLimit(2...6)
                        .font(.system(.body, design: .monospaced))
                        .padding(10)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                        .focused($isMathFocused)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            
            // Live LaTeX Preview with explicit math wrappers to force correct rendering
            if !block.content.isEmpty && (block.type == QuestionBlockType.math.rawValue || (block.type == QuestionBlockType.graph.rawValue && block.graphType == QuestionGraphType.equation.rawValue)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Preview:")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.teal)
                    
                    LatexView(latex: "$$ " + block.content.parsedMathToLatex + " $$")
                        .frame(minHeight: 45)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
    
    private func iconForType() -> String {
        switch block.type {
        case QuestionBlockType.text.rawValue: return "text.alignleft"
        case QuestionBlockType.math.rawValue: return "x.squareroot"
        case QuestionBlockType.graph.rawValue: return "chart.xyaxis.line"
        default: return "cube"
        }
    }
    
    private func colorForType() -> Color {
        switch block.type {
        case QuestionBlockType.text.rawValue: return .blue
        case QuestionBlockType.math.rawValue: return .orange
        case QuestionBlockType.graph.rawValue: return .purple
        default: return .primary
        }
    }
}

// MARK: - Advanced WebAssign Math Keypad
fileprivate enum KeypadTab: String, CaseIterable {
    case num = "123"
    case fn = "ƒ(x)"
    case sym = "αβγ"
}

fileprivate struct MathKeypadView: View {
    @Binding var text: String
    @State private var currentTab: KeypadTab = .num
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
    
    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $currentTab) {
                ForEach(KeypadTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)
            
            LazyVGrid(columns: columns, spacing: 8) {
                switch currentTab {
                case .num:
                    keyButton("7", display: "7")
                    keyButton("8", display: "8")
                    keyButton("9", display: "9")
                    keyButton(" / ", display: "÷", color: Color(UIColor.systemGray5))
                    actionButton(systemName: "delete.left.fill", action: backspace, color: Color(UIColor.systemGray4))
                    
                    keyButton("4", display: "4")
                    keyButton("5", display: "5")
                    keyButton("6", display: "6")
                    keyButton(" * ", display: "×", color: Color(UIColor.systemGray5))
                    keyButton("(", display: "(", color: Color(UIColor.systemGray5))
                    
                    keyButton("1", display: "1")
                    keyButton("2", display: "2")
                    keyButton("3", display: "3")
                    keyButton(" - ", display: "-", color: Color(UIColor.systemGray5))
                    keyButton(")", display: ")", color: Color(UIColor.systemGray5))
                    
                    keyButton("0", display: "0")
                    keyButton(".", display: ".")
                    keyButton(" = ", display: "=", color: Color(UIColor.systemGray5))
                    keyButton(" + ", display: "+", color: Color(UIColor.systemGray5))
                    actionButton(systemName: "space", action: { text.append(" ") }, color: Color(UIColor.systemGray4))
                    
                case .fn:
                    // Notice these inject plain-text strings, not raw LaTeX
                    keyButton("sin(", display: "sin")
                    keyButton("cos(", display: "cos")
                    keyButton("tan(", display: "tan")
                    keyButton("ln(", display: "ln")
                    actionButton(systemName: "delete.left.fill", action: backspace, color: Color(UIColor.systemGray4))
                    
                    keyButton("csc(", display: "csc")
                    keyButton("sec(", display: "sec")
                    keyButton("cot(", display: "cot")
                    keyButton("log(", display: "log")
                    keyButton("^(", display: "xⁿ", color: Color(UIColor.systemGray5))
                    
                    keyButton("x", display: "x", color: Color(UIColor.systemGray5))
                    keyButton("y", display: "y", color: Color(UIColor.systemGray5))
                    keyButton("e^(", display: "eⁿ", color: Color(UIColor.systemGray5))
                    keyButton("}", display: "}", color: Color(UIColor.systemGray5))
                    keyButton("√(", display: "√", color: Color(UIColor.systemGray5))
                    
                    keyButton("a", display: "a", color: Color(UIColor.systemGray5))
                    keyButton("b", display: "b", color: Color(UIColor.systemGray5))
                    keyButton("{", display: "{", color: Color(UIColor.systemGray5))
                    keyButton("}", display: "}", color: Color(UIColor.systemGray5))
                    actionButton(systemName: "space", action: { text.append(" ") }, color: Color(UIColor.systemGray4))
                    
                case .sym:
                    keyButton("π", display: "π")
                    keyButton("θ", display: "θ")
                    keyButton("α", display: "α")
                    keyButton("β", display: "β")
                    actionButton(systemName: "delete.left.fill", action: backspace, color: Color(UIColor.systemGray4))
                    
                    keyButton(" ≤ ", display: "≤")
                    keyButton(" ≥ ", display: "≥")
                    keyButton(" ≠ ", display: "≠")
                    keyButton(" ≈ ", display: "≈")
                    keyButton(" / ", display: "a/b", color: Color(UIColor.systemGray5))
                    
                    keyButton("∫", display: "∫")
                    keyButton("∑", display: "∑")
                    keyButton("∞", display: "∞")
                    keyButton("°", display: "°")
                    keyButton("^(2)", display: "x²", color: Color(UIColor.systemGray5))
                    
                    keyButton("(", display: "(", color: Color(UIColor.systemGray5))
                    keyButton(")", display: ")", color: Color(UIColor.systemGray5))
                    keyButton("{", display: "{", color: Color(UIColor.systemGray5))
                    keyButton("}", display: "}", color: Color(UIColor.systemGray5))
                    actionButton(systemName: "space", action: { text.append(" ") }, color: Color(UIColor.systemGray4))
                }
            }
        }
        .padding(10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
    
    private func backspace() {
        if !text.isEmpty {
            text.removeLast()
        }
    }
    
    @ViewBuilder
    private func keyButton(_ insertString: String, display: String, color: Color = Color(UIColor.systemBackground)) -> some View {
        Button(action: { text.append(insertString) }) {
            Text(display)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color)
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func actionButton(systemName: String, action: @escaping () -> Void, color: Color) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color)
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
}
