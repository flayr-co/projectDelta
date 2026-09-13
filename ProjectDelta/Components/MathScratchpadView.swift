//
//  MathScratchpadView.swift
//  ProjectDelta
//

import SwiftUI
import Observation

// MARK: - Core Data Models

enum TokenType: String, Hashable {
    case number, variable, operatorSymbol, function, structural
}

struct MathToken: Identifiable, Hashable {
    let id = UUID()
    var value: String
    var type: TokenType
}

// MARK: - View Model

@MainActor
@Observable
class MathScratchpadViewModel {
    var lines: [[MathToken]] = [[]]
    var activeLineIndex: Int = 0
    var cursorIndex: Int = 0
    
    var activeVariables: [String] = ["x", "y", "θ"]
    
    var isEmpty: Bool {
        lines.count == 1 && lines[0].isEmpty
    }
    
    func insert(_ value: String, type: TokenType) {
        if type == .number && cursorIndex > 0 {
            let prevToken = lines[activeLineIndex][cursorIndex - 1]
            if prevToken.type == .number {
                lines[activeLineIndex][cursorIndex - 1].value += value
                return
            }
        } else if type == .variable && cursorIndex > 0 {
            let prevToken = lines[activeLineIndex][cursorIndex - 1]
            if prevToken.type == .variable {
                lines[activeLineIndex][cursorIndex - 1].value += value
                
                // Hardware Keyboard Macro Expansion (Auto-closing brackets)
                let merged = lines[activeLineIndex][cursorIndex - 1].value
                switch merged {
                case "sin":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\sin(", type: .function)
                    lines[activeLineIndex].insert(MathToken(value: ")", type: .structural), at: cursorIndex)
                case "cos":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\cos(", type: .function)
                    lines[activeLineIndex].insert(MathToken(value: ")", type: .structural), at: cursorIndex)
                case "tan":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\tan(", type: .function)
                    lines[activeLineIndex].insert(MathToken(value: ")", type: .structural), at: cursorIndex)
                case "ln":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\ln(", type: .function)
                    lines[activeLineIndex].insert(MathToken(value: ")", type: .structural), at: cursorIndex)
                case "log":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\log_{10}(", type: .function)
                    lines[activeLineIndex].insert(MathToken(value: ")", type: .structural), at: cursorIndex)
                case "sqrt":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\sqrt{", type: .function)
                    lines[activeLineIndex].insert(MathToken(value: "}", type: .structural), at: cursorIndex)
                case "pi":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\pi", type: .function)
                case "theta":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\theta", type: .function)
                default: break
                }
                return
            }
        }
        
        let token = MathToken(value: value, type: type)
        lines[activeLineIndex].insert(token, at: cursorIndex)
        cursorIndex += 1
    }
    
    func backspace() {
        if cursorIndex > 0 {
            let prevToken = lines[activeLineIndex][cursorIndex - 1]
            
            if prevToken.type == .number && prevToken.value.count > 1 {
                var modifiedToken = prevToken
                modifiedToken.value.removeLast()
                lines[activeLineIndex][cursorIndex - 1] = modifiedToken
            } else if prevToken.type == .variable && prevToken.value.count > 1 {
                var modifiedToken = prevToken
                modifiedToken.value.removeLast()
                lines[activeLineIndex][cursorIndex - 1] = modifiedToken
            } else {
                lines[activeLineIndex].remove(at: cursorIndex - 1)
                cursorIndex -= 1
            }
        } else if activeLineIndex > 0 {
            if lines[activeLineIndex].isEmpty {
                lines.remove(at: activeLineIndex)
                activeLineIndex -= 1
                cursorIndex = lines[activeLineIndex].count
            }
        }
    }
    
    func newLine() {
        activeLineIndex += 1
        lines.insert([], at: activeLineIndex)
        cursorIndex = 0
    }
    
    func clearAll() {
        lines = [[]]
        activeLineIndex = 0
        cursorIndex = 0
    }
    
    func moveCursor(to index: Int, on line: Int) {
        activeLineIndex = line
        cursorIndex = index
    }
    
    func moveCursorRight() {
        if cursorIndex < lines[activeLineIndex].count {
            cursorIndex += 1
        }
    }
    
    func moveCursorLeft() {
        if cursorIndex > 0 {
            cursorIndex -= 1
        }
    }
    
    // Parses and loads an initial equation into the scratchpad without destroying LaTeX formatting
    func loadEquation(_ equation: String) {
        self.clearAll()
        
        // Removed aggressive LaTeX stripping to keep structure intact
        let cleanInput = equation.replacingOccurrences(of: " ", with: "")
        
        var parsedTokens: [MathToken] = []
        var currentNumber = ""
        var currentVariable = ""
        
        let flushNumber = {
            if !currentNumber.isEmpty {
                parsedTokens.append(MathToken(value: currentNumber, type: .number))
                currentNumber = ""
            }
        }
        
        let flushVariable = {
            if !currentVariable.isEmpty {
                parsedTokens.append(MathToken(value: currentVariable, type: .variable))
                currentVariable = ""
            }
        }
        
        let chars = Array(cleanInput)
        var i = 0
        
        while i < chars.count {
            let char = chars[i]
            if char.isNumber || char == "." {
                flushVariable()
                currentNumber.append(char)
            } else if char.isLetter || char == "θ" {
                flushNumber()
                currentVariable.append(char)
            } else {
                flushNumber()
                flushVariable()
                parsedTokens.append(MathToken(value: String(char), type: .operatorSymbol))
            }
            i += 1
        }
        
        flushNumber()
        flushVariable()
        
        if !parsedTokens.isEmpty {
            self.lines[0] = parsedTokens
            // Automatically push to a new line so the loaded equation renders
            self.newLine()
        }
    }
}

// MARK: - Main Canvas View

struct MathScratchpadView: View {
    @Bindable var viewModel: MathScratchpadViewModel
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isCanvasFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.and.scribble")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(red: 0.15, green: 0.85, blue: 0.65))
                    Text("Scratchpad")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.snappy) { viewModel.clearAll() }
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.red)
                        .padding(9)
                        .background(Color.red.opacity(0.12), in: .circle)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            // Live Preview of the Active Equation
            let activeLineString = viewModel.lines[viewModel.activeLineIndex].map { $0.value }.joined()
            if !activeLineString.isEmpty {
                LatexView(latex: "$$ \(activeLineString) $$")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                    )
                    .padding(.horizontal, 20)
            }
            
            // Equation Canvas
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(0..<viewModel.lines.count, id: \.self) { lineIndex in
                            MathLineView(
                                tokens: viewModel.lines[lineIndex],
                                isActive: lineIndex == viewModel.activeLineIndex,
                                cursorIndex: lineIndex == viewModel.activeLineIndex ? viewModel.cursorIndex : nil,
                                onCursorTap: { newIndex in
                                    withAnimation(.snappy) {
                                        viewModel.moveCursor(to: newIndex, on: lineIndex)
                                    }
                                }
                            )
                            .id(lineIndex)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(DotGridBackground())
                .focusable()
                .focused($isCanvasFocused)
                // Hardware Keyboard Intercepts mapping keystrokes to view model inputs
                .onKeyPress(phases: .down) { press in
                    if press.key == .delete || press.key == KeyEquivalent("\u{7F}") || press.key == KeyEquivalent("\u{08}") {
                        viewModel.backspace()
                        return .handled
                    }
                    if press.key == .return {
                        viewModel.newLine()
                        return .handled
                    }
                    if press.key == .rightArrow {
                        viewModel.moveCursorRight()
                        return .handled
                    }
                    if press.key == .leftArrow {
                        viewModel.moveCursorLeft()
                        return .handled
                    }
                    if press.key == .space {
                        return .handled // Gracefully consume spacebar so it doesn't beep
                    }
                    if let char = press.characters.first {
                        if char.isNumber {
                            viewModel.insert(String(char), type: .number)
                            return .handled
                        } else if char.isLetter {
                            viewModel.insert(String(char), type: .variable)
                            return .handled
                        } else if ["+", "-", "=", "(", ")", "/", "*", "^", ".", "<", ">"].contains(char) {
                            let mappedChar = char == "/" ? "÷" : (char == "*" ? "×" : String(char))
                            viewModel.insert(mappedChar, type: .operatorSymbol)
                            return .handled
                        }
                    }
                    return .ignored
                }
                .onChange(of: viewModel.activeLineIndex) { _, newIndex in
                    withAnimation(.snappy) {
                        proxy.scrollTo(newIndex, anchor: .bottom)
                    }
                }
            }
            
            // Custom Keypad
            MathKeypadView(viewModel: viewModel)
        }
        .background(
            ZStack {
                if colorScheme == .dark {
                    Color(red: 0.08, green: 0.09, blue: 0.11)
                } else {
                    Color(red: 0.98, green: 0.98, blue: 0.99)
                }
            }
        )
        .onAppear {
            isCanvasFocused = true
        }
    }
}

// MARK: - Background Enhancements

struct DotGridBackground: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let spacing: CGFloat = 24
                for x in stride(from: 0, through: geometry.size.width, by: spacing) {
                    for y in stride(from: 0, through: geometry.size.height, by: spacing) {
                        path.addEllipse(in: CGRect(x: x, y: y, width: 2, height: 2))
                    }
                }
            }
            .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.05))
        }
    }
}

// MARK: - Layout Engine
struct FlowLayout: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing, lineSpacing: lineSpacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing, lineSpacing: lineSpacing)
        for row in result.rows {
            var currentX = bounds.minX
            let rowY = bounds.minY + row.yOffset
            for element in row.elements {
                element.subview.place(at: CGPoint(x: currentX, y: rowY), proposal: .unspecified)
                currentX += element.size.width + spacing
            }
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var rows: [Row] = []

        struct Row {
            var elements: [(size: CGSize, subview: LayoutSubview)] = []
            var yOffset: CGFloat = 0
            var width: CGFloat = 0
            var height: CGFloat = 0
        }

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat, lineSpacing: CGFloat) {
            var currentRow = Row()
            var currentY: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentRow.width + size.width > maxWidth && !currentRow.elements.isEmpty {
                    currentRow.yOffset = currentY
                    rows.append(currentRow)
                    currentY += currentRow.height + lineSpacing
                    currentRow = Row()
                }

                currentRow.elements.append((size, subview))
                currentRow.width += size.width + (currentRow.elements.count > 1 ? spacing : 0)
                currentRow.height = max(currentRow.height, size.height)
            }

            if !currentRow.elements.isEmpty {
                currentRow.yOffset = currentY
                rows.append(currentRow)
                currentY += currentRow.height
            }

            size = CGSize(width: maxWidth, height: currentY)
        }
    }
}

// MARK: - Line & Token Rendering

struct MathLineView: View {
    let tokens: [MathToken]
    let isActive: Bool
    let cursorIndex: Int?
    let onCursorTap: (Int) -> Void
    
    let emeraldAccent = Color(red: 0.15, green: 0.85, blue: 0.65)
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(isActive ? emeraldAccent : Color.clear)
                .frame(width: 3.5)
                .shadow(color: isActive ? emeraldAccent.opacity(0.6) : Color.clear, radius: 4, y: 0)
                .padding(.vertical, 6)
            
            if isActive {
                FlowLayout(spacing: 0, lineSpacing: 10) {
                    Color.clear
                        .frame(width: 10, height: 32)
                        .contentShape(Rectangle())
                        .onTapGesture { onCursorTap(0) }
                        .overlay(alignment: .trailing) {
                            if cursorIndex == 0 { BlinkingCursor() }
                        }
                    
                    ForEach(0..<tokens.count, id: \.self) { i in
                        TokenView(token: tokens[i])
                            .onTapGesture { onCursorTap(i + 1) }
                            .overlay(alignment: .trailing) {
                                if cursorIndex == i + 1 { BlinkingCursor() }
                            }
                    }
                }
                .padding(.vertical, 12)
                .padding(.trailing, 12)
            } else {
                let latexString = tokens.map { $0.value }.joined()
                
                if latexString.isEmpty {
                    Color.clear
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { onCursorTap(tokens.count) }
                } else {
                    LatexView(latex: "$$ \(latexString) $$")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.leading, 14)
                        .contentShape(Rectangle())
                        .onTapGesture { onCursorTap(tokens.count) }
                }
            }
        }
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isActive ? (colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)) : Color.clear)
        )
    }
}

struct BlinkingCursor: View {
    @State private var isBlinking = false
    let emeraldAccent = Color(red: 0.15, green: 0.85, blue: 0.65)
    
    var body: some View {
        Capsule()
            .fill(emeraldAccent)
            .frame(width: 2.5, height: 22)
            .offset(x: 1.25)
            .shadow(color: emeraldAccent.opacity(0.8), radius: 4, y: 0)
            .opacity(isBlinking ? 1.0 : 0.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isBlinking = true
                }
            }
    }
}

struct TokenView: View {
    let token: MathToken
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(token.value)
            .font(.system(size: 20, weight: weightForType(token.type), design: .rounded))
            .italic(token.type == .variable)
            .foregroundStyle(colorForType(token.type))
            .padding(.horizontal, paddingForType(token.type))
            .background(backgroundForType(token.type), in: .rect(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
    }
    
    private func paddingForType(_ type: TokenType) -> CGFloat {
        switch type {
        case .operatorSymbol, .structural: return 3
        case .function: return 2
        case .number, .variable: return 0.5
        }
    }
    
    private func weightForType(_ type: TokenType) -> Font.Weight {
        switch type {
        case .operatorSymbol: return .bold
        case .number, .variable: return .medium
        default: return .medium
        }
    }
    
    private func colorForType(_ type: TokenType) -> Color {
        switch type {
        case .number: return .primary
        case .variable: return colorScheme == .dark ? Color(red: 0.45, green: 0.82, blue: 1.0) : Color.blue
        case .operatorSymbol: return Color(red: 1.0, green: 0.60, blue: 0.15)
        case .function: return colorScheme == .dark ? Color(red: 0.85, green: 0.55, blue: 1.0) : Color.purple
        case .structural: return .secondary
        }
    }
    
    private func backgroundForType(_ type: TokenType) -> Color {
        switch type {
        case .function: return Color.primary.opacity(0.04)
        default: return Color.clear
        }
    }
}

// MARK: - Custom Context-Aware Keypad

struct MathKeypadView: View {
    @Bindable var viewModel: MathScratchpadViewModel
    @State private var triggerHaptic = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 10) {
            // Context Variables & Functions Rail
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(["x", "y", "θ", "π"], id: \.self) { variable in
                        let isPi = variable == "π"
                        KeypadButton(text: variable, type: isPi ? .function : .variable, style: .variable) {
                            viewModel.insert(isPi ? "\\pi" : variable, type: isPi ? .function : .variable)
                            triggerHaptic.toggle()
                        }
                        .frame(width: 50)
                    }
                    
                    Divider().frame(height: 22)
                    
                    ForEach(["sin", "cos", "tan", "ln"], id: \.self) { fn in
                        KeypadButton(text: fn, type: .function, style: .function) {
                            viewModel.insert("\\\(fn)(", type: .function)
                            viewModel.insert(")", type: .structural)
                            viewModel.moveCursorLeft()
                            triggerHaptic.toggle()
                        }
                        .frame(width: 54)
                    }
                    
                    KeypadButton(text: "√", type: .function, style: .function) {
                        viewModel.insert("\\sqrt{", type: .function)
                        viewModel.insert("}", type: .structural)
                        viewModel.moveCursorLeft()
                        triggerHaptic.toggle()
                    }
                    .frame(width: 50)
                    
                    Divider().frame(height: 22)
                    
                    KeypadButton(icon: "arrow.right", style: .action) {
                        viewModel.moveCursorRight()
                        triggerHaptic.toggle()
                    }
                    .frame(width: 54)
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 42)
            .padding(.top, 14)
            
            // Grid-based Math Keypad
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    KeypadButton(text: "7", style: .number) { viewModel.insert("7", type: .number); triggerHaptic.toggle() }
                    KeypadButton(text: "8", style: .number) { viewModel.insert("8", type: .number); triggerHaptic.toggle() }
                    KeypadButton(text: "9", style: .number) { viewModel.insert("9", type: .number); triggerHaptic.toggle() }
                    KeypadButton(text: "÷", type: .operatorSymbol, style: .operator) { viewModel.insert("÷", type: .operatorSymbol); triggerHaptic.toggle() }
                    KeypadButton(icon: "delete.left.fill", style: .destructive) { viewModel.backspace(); triggerHaptic.toggle() }
                }
                GridRow {
                    KeypadButton(text: "4", style: .number) { viewModel.insert("4", type: .number); triggerHaptic.toggle() }
                    KeypadButton(text: "5", style: .number) { viewModel.insert("5", type: .number); triggerHaptic.toggle() }
                    KeypadButton(text: "6", style: .number) { viewModel.insert("6", type: .number); triggerHaptic.toggle() }
                    KeypadButton(text: "×", type: .operatorSymbol, style: .operator) { viewModel.insert("×", type: .operatorSymbol); triggerHaptic.toggle() }
                    KeypadButton(text: "^", type: .operatorSymbol, style: .operator) { viewModel.insert("^", type: .operatorSymbol); triggerHaptic.toggle() }
                }
                GridRow {
                    KeypadButton(text: "1", style: .number) { viewModel.insert("1", type: .number); triggerHaptic.toggle() }
                    KeypadButton(text: "2", style: .number) { viewModel.insert("2", type: .number); triggerHaptic.toggle() }
                    KeypadButton(text: "3", style: .number) { viewModel.insert("3", type: .number); triggerHaptic.toggle() }
                    KeypadButton(text: "-", type: .operatorSymbol, style: .operator) { viewModel.insert("-", type: .operatorSymbol); triggerHaptic.toggle() }
                    KeypadButton(text: "=", type: .operatorSymbol, style: .action) { viewModel.insert("=", type: .operatorSymbol); triggerHaptic.toggle() }
                }
                GridRow {
                    KeypadButton(text: ".", style: .number) { viewModel.insert(".", type: .number); triggerHaptic.toggle() }
                    KeypadButton(text: "0", style: .number) { viewModel.insert("0", type: .number); triggerHaptic.toggle() }
                    KeypadButton(text: "( )", type: .structural, style: .number) { viewModel.insert("(", type: .structural); triggerHaptic.toggle() }
                    KeypadButton(text: "+", type: .operatorSymbol, style: .operator) { viewModel.insert("+", type: .operatorSymbol); triggerHaptic.toggle() }
                    KeypadButton(icon: "return", style: .confirm) { viewModel.newLine(); triggerHaptic.toggle() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.12, green: 0.13, blue: 0.15) : Color(white: 0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: colorScheme == .dark ? [Color.white.opacity(0.12), Color.white.opacity(0.02)] : [Color.black.opacity(0.06), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 24, y: -6)
        )
        .sensoryFeedback(.selection, trigger: triggerHaptic)
    }
}

// MARK: - Keypad Button System

enum KeypadButtonStyleType {
    case number, `operator`, action, confirm, destructive, variable, function
}

struct KeypadButton: View {
    var text: String? = nil
    var icon: String? = nil
    var type: TokenType = .number
    var style: KeypadButtonStyleType
    var action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.25 : 0.04), radius: 2, y: 1)
                
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(foregroundColor)
                } else if let text = text {
                    Text(text)
                        .font(.system(size: 22, weight: type == .operatorSymbol ? .bold : .medium, design: .rounded))
                        .italic(type == .variable)
                        .foregroundStyle(foregroundColor)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(KeypadPressStyle())
    }
    
    private var backgroundColor: AnyShapeStyle {
        switch style {
        case .number:
            return AnyShapeStyle(colorScheme == .dark ? Color(white: 0.18) : Color.white)
        case .operator:
            return AnyShapeStyle(colorScheme == .dark ? Color.orange.opacity(0.18) : Color.orange.opacity(0.12))
        case .action:
            return AnyShapeStyle(colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.12))
        case .confirm:
            return AnyShapeStyle(LinearGradient(colors: [Color(red: 0.15, green: 0.85, blue: 0.65), Color(red: 0.10, green: 0.70, blue: 0.50)], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .destructive:
            return AnyShapeStyle(colorScheme == .dark ? Color.red.opacity(0.2) : Color.red.opacity(0.12))
        case .variable:
            return AnyShapeStyle(colorScheme == .dark ? Color(white: 0.16) : Color.blue.opacity(0.08))
        case .function:
            return AnyShapeStyle(colorScheme == .dark ? Color(white: 0.16) : Color.purple.opacity(0.08))
        }
    }
    
    private var borderColor: Color {
        if colorScheme == .dark {
            switch style {
            case .operator: return Color.orange.opacity(0.35)
            case .action: return Color.blue.opacity(0.35)
            case .destructive: return Color.red.opacity(0.35)
            case .confirm: return Color.clear
            default: return Color.white.opacity(0.08)
            }
        } else {
            switch style {
            case .confirm: return Color.clear
            default: return Color.black.opacity(0.04)
            }
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .number: return .primary
        case .operator: return Color(red: 1.0, green: 0.60, blue: 0.15)
        case .action: return colorScheme == .dark ? Color(red: 0.45, green: 0.82, blue: 1.0) : Color.blue
        case .confirm: return .white
        case .destructive: return colorScheme == .dark ? Color(red: 1.0, green: 0.45, blue: 0.45) : Color.red
        case .variable: return colorScheme == .dark ? Color(red: 0.45, green: 0.82, blue: 1.0) : Color.blue
        case .function: return colorScheme == .dark ? Color(red: 0.85, green: 0.55, blue: 1.0) : Color.purple
        }
    }
}

struct KeypadPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}
