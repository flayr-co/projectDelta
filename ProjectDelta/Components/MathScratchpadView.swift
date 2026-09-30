//
//  MathScratchpadView.swift
//  ProjectDelta
//

import SwiftUI
import Observation

// MARK: - Core Data Models

enum TokenType: String, Hashable, Codable {
    case number, variable, operatorSymbol, function, structural
}

struct MathToken: Identifiable, Hashable, Codable {
    var id = UUID()
    var value: String
    var type: TokenType
    var isScratchedOff: Bool = false
    var highlightColor: String? = nil
}

// MARK: - View Model

@MainActor
@Observable
class MathScratchpadViewModel {
    var lines: [[MathToken]] = [[]]
    var activeLineIndex: Int = 0
    var cursorIndex: Int = 0
    
    var activeVariables: [String] = ["x", "y", "θ"]
    var isCalculatorEnabled: Bool = false
    var hasBeenEdited: Bool = false
    
    // Internal clipboard perfectly preserves highlights and scratch-offs without parsing raw text
    static var internalClipboard: [MathToken]? = nil
    static var internalClipboardString: String? = nil
    
    // MARK: - Undo State Management
    private struct ScratchpadState {
        let lines: [[MathToken]]
        let activeLineIndex: Int
        let cursorIndex: Int
    }
    
    private var undoStack: [ScratchpadState] = []
    
    private func saveState() {
        undoStack.append(ScratchpadState(lines: lines, activeLineIndex: activeLineIndex, cursorIndex: cursorIndex))
        if undoStack.count > 100 { undoStack.removeFirst() }
    }
    
    func undo() {
        guard let previousState = undoStack.popLast() else { return }
        self.lines = previousState.lines
        self.activeLineIndex = previousState.activeLineIndex
        self.cursorIndex = previousState.cursorIndex
        self.hasBeenEdited = true
    }
    
    func applyHighlight(to range: ClosedRange<Int>, on lineIndex: Int, color: String?) {
        saveState()
        var updatedLine = lines[lineIndex]
        for i in range {
            updatedLine[i].highlightColor = color
        }
        lines[lineIndex] = updatedLine
        hasBeenEdited = true
    }
        
    func applyScratchOff(to range: ClosedRange<Int>, on lineIndex: Int) {
        saveState()
        var updatedLine = lines[lineIndex]
        let allScratched = range.allSatisfy { updatedLine[$0].isScratchedOff }
        for i in range {
            updatedLine[i].isScratchedOff = !allScratched
        }
        lines[lineIndex] = updatedLine
        hasBeenEdited = true
    }
    
    func convertToFraction(range: ClosedRange<Int>, on lineIndex: Int) {
        saveState()
        let line = lines[lineIndex]
        let selectedTokens = Array(line[range])
        
        var newTokens: [MathToken] = []
        newTokens.append(MathToken(value: "\\frac{", type: .function))
        
        if let divIndex = selectedTokens.firstIndex(where: { $0.value == "÷" || $0.value == "/" }) {
            let numTokens = Array(selectedTokens[..<divIndex])
            let denTokens = Array(selectedTokens[(divIndex + 1)...])
            newTokens.append(contentsOf: numTokens)
            newTokens.append(MathToken(value: "}{", type: .structural))
            newTokens.append(contentsOf: denTokens)
        } else {
            newTokens.append(contentsOf: selectedTokens)
            newTokens.append(MathToken(value: "}{", type: .structural))
        }
        
        newTokens.append(MathToken(value: "}", type: .structural))
        
        lines[lineIndex].replaceSubrange(range, with: newTokens)
        cursorIndex = range.lowerBound + newTokens.count
        hasBeenEdited = true
    }
    
    var isEmpty: Bool {
        lines.allSatisfy { $0.isEmpty }
    }
    
    func insert(_ value: String, type: TokenType) {
        saveState()
        hasBeenEdited = true
        
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
                
                let merged = lines[activeLineIndex][cursorIndex - 1].value.lowercased()
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
                case "lim":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\lim_{x \\to ", type: .function)
                    lines[activeLineIndex].insert(MathToken(value: "}", type: .structural), at: cursorIndex)
                    lines[activeLineIndex].insert(MathToken(value: "(", type: .structural), at: cursorIndex + 1)
                    lines[activeLineIndex].insert(MathToken(value: ")", type: .structural), at: cursorIndex + 2)
                case "sum":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\sum_{", type: .function)
                    lines[activeLineIndex].insert(MathToken(value: "}", type: .structural), at: cursorIndex)
                    lines[activeLineIndex].insert(MathToken(value: "^{", type: .structural), at: cursorIndex + 1)
                    lines[activeLineIndex].insert(MathToken(value: "}", type: .structural), at: cursorIndex + 2)
                case "abs":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "|", type: .structural)
                    lines[activeLineIndex].insert(MathToken(value: "|", type: .structural), at: cursorIndex)
                case "pi":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\pi", type: .function)
                case "theta":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\theta", type: .function)
                case "infinity", "inf":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\infty", type: .number)
                case "alpha":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\alpha", type: .function)
                case "beta":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\beta", type: .function)
                case "int":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "\\int", type: .function)
                case "deg":
                    lines[activeLineIndex][cursorIndex - 1] = MathToken(value: "^{\\circ}", type: .operatorSymbol)
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
        saveState()
        hasBeenEdited = true
        
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
        saveState()
        hasBeenEdited = true
        activeLineIndex += 1
        lines.insert([], at: activeLineIndex)
        cursorIndex = 0
    }
    
    func insertLine(at index: Int) {
        saveState()
        hasBeenEdited = true
        lines.insert([], at: index)
        activeLineIndex = index
        cursorIndex = 0
    }
    
    func clearAll() {
        saveState()
        hasBeenEdited = true
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
    
    func calculateCurrentLine() -> String? {
        guard isCalculatorEnabled else { return nil }
        let tokens = lines[activeLineIndex]
        guard !tokens.isEmpty else { return nil }
        
        let valid = tokens.allSatisfy { $0.type == .number || ["+", "-", "×", "÷", "(", ")", ".", "\\pi"].contains($0.value) }
        guard valid else { return nil }
        
        var mathString = ""
        for t in tokens {
            if t.value == "×" { mathString += "*" }
            else if t.value == "÷" { mathString += ".0/" }
            else if t.value == "\\pi" { mathString += "3.14159265359" }
            else { mathString += t.value }
        }
        
        let allowed = CharacterSet(charactersIn: "0123456789+-*/(). ")
        guard mathString.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        
        let pattern = "([\\+\\-\\*\\/]{2,}|[\\+\\-\\*\\/]$|^[\\*\\/])|\\(\\)"
        if mathString.range(of: pattern, options: .regularExpression) != nil { return nil }
        
        var open = 0
        for char in mathString {
            if char == "(" { open += 1 }
            if char == ")" { open -= 1 }
            if open < 0 { return nil }
        }
        if open != 0 { return nil }
        
        let exp = NSExpression(format: mathString)
        if let result = exp.expressionValue(with: nil, context: nil) as? Double {
            if result.isNaN || result.isInfinite { return nil }
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 5
            return formatter.string(from: NSNumber(value: result))
        }
        return nil
    }
    
    func loadEquation(_ equation: String) {
        self.lines = [[]]
        let cleanInput = equation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanInput.isEmpty else { return }
        
        let monolithToken = MathToken(value: cleanInput, type: .structural)
        self.lines[0] = [monolithToken]
        
        // Auto-generate the next empty line so the user can immediately paste or start typing
        self.lines.append([])
        self.activeLineIndex = 1
        self.cursorIndex = 0
        
        // Auto-loads do not flag as user edits, preventing DB pollution
        self.hasBeenEdited = false
    }
    
    // MARK: - Rich Copy & Paste
    
    func copyLine(at index: Int) {
        let tokens = lines[index]
        Self.internalClipboard = tokens
        let cleanLatex = tokens.map { $0.value }.joined()
        Self.internalClipboardString = cleanLatex
        
        #if os(iOS)
        UIPasteboard.general.string = cleanLatex
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cleanLatex, forType: .string)
        #endif
    }
    
    func copyActiveLine() {
        copyLine(at: activeLineIndex)
    }
    
    func pasteToLine(at index: Int) {
        saveState()
        hasBeenEdited = true
        
        #if os(iOS)
        let text = UIPasteboard.general.string ?? ""
        #elseif os(macOS)
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        #endif
        
        if text == Self.internalClipboardString, let tokens = Self.internalClipboard {
            let uniqueTokens = tokens.map { MathToken(value: $0.value, type: $0.type, isScratchedOff: $0.isScratchedOff, highlightColor: $0.highlightColor) }
            
            if lines[index].isEmpty {
                lines[index] = uniqueTokens
            } else {
                lines[index].insert(contentsOf: uniqueTokens, at: index == activeLineIndex ? cursorIndex : lines[index].count)
                if index == activeLineIndex { cursorIndex += uniqueTokens.count }
            }
        } else if !text.isEmpty {
            self.pasteEquation(text, at: index)
        }
    }
    
    func pasteToActiveLine() {
        pasteToLine(at: activeLineIndex)
    }
    
    private func pasteEquation(_ equation: String, at lineIndex: Int) {
        let cleanInput = equation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanInput.isEmpty else { return }
        
        let monolithToken = MathToken(value: cleanInput, type: .structural)
        if lineIndex < lines.count {
            if lines[lineIndex].isEmpty {
                lines[lineIndex] = [monolithToken]
            } else {
                lines[lineIndex].insert(monolithToken, at: cursorIndex)
                cursorIndex += 1
            }
        }
    }
    
    // MARK: - Database Serialization
    func exportStateAsJSON() -> String? {
        guard let data = try? JSONEncoder().encode(lines) else { return nil }
        return String(data: data, encoding: .utf8)
    }
        
    func importStateFromJSON(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([[MathToken]].self, from: data) else { return }
        
        self.lines = decoded
        self.activeLineIndex = max(0, decoded.count - 1)
        self.cursorIndex = self.lines[activeLineIndex].count
        self.undoStack.removeAll()
        self.hasBeenEdited = false
    }
}

// MARK: - Drag Delegate

struct LineDropDelegate: DropDelegate {
    let item: Int
    let viewModel: MathScratchpadViewModel
    @Binding var draggedItem: Int?
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem, draggedItem != item else { return }
        withAnimation(.snappy) {
            let from = draggedItem
            let to = item
            
            let movedLine = viewModel.lines.remove(at: from)
            viewModel.lines.insert(movedLine, at: to)
            
            if viewModel.activeLineIndex == from {
                viewModel.activeLineIndex = to
            } else if viewModel.activeLineIndex == to {
                viewModel.activeLineIndex = from
            }
            
            self.draggedItem = to
        }
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}

// MARK: - Main Canvas View

struct MathScratchpadView: View {
    @Bindable var viewModel: MathScratchpadViewModel
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isCanvasFocused: Bool
    
    // Hardware/Software Keyboard Bridge State
    @FocusState private var isNativeKeyboardFocused: Bool
    @State private var nativeInputString: String = " "
    @State private var showCustomKeypad: Bool = true
    
    @State private var isKeypadExpanded: Bool = false
    @State private var draggedLineIndex: Int? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag-Friendly Header
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
                
                HStack(spacing: 12) {
                    // Native Keyboard Toggle
                    Button(action: {
                        withAnimation(.snappy) {
                            if isNativeKeyboardFocused {
                                isNativeKeyboardFocused = false
                                showCustomKeypad = true
                            } else {
                                showCustomKeypad = false
                                isNativeKeyboardFocused = true
                            }
                        }
                    }) {
                        Image(systemName: isNativeKeyboardFocused ? "keyboard.chevron.compact.down" : "keyboard")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(isNativeKeyboardFocused ? Color.white : Color.blue)
                            .padding(8)
                            .background(isNativeKeyboardFocused ? Color.blue : Color.blue.opacity(0.12), in: .circle)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.snappy) { viewModel.isCalculatorEnabled.toggle() }
                    }) {
                        Image(systemName: viewModel.isCalculatorEnabled ? "equal.circle.fill" : "plus.forwardslash.minus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(viewModel.isCalculatorEnabled ? Color.white : Color.green)
                            .padding(8)
                            .background(viewModel.isCalculatorEnabled ? Color.green : Color.green.opacity(0.12), in: .circle)
                    }
                    .buttonStyle(.plain)
                    
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
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .contentShape(Rectangle()) // Makes the entire header a reliable drag target for the sheet
            
            // Equation Canvas
            ZStack {
                // Invisible Native Keyboard Bridge
                TextField("", text: $nativeInputString)
                    .focused($isNativeKeyboardFocused)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .onChange(of: nativeInputString) { oldValue, newValue in
                        guard newValue != " " else { return }
                        
                        if newValue.isEmpty {
                            viewModel.backspace()
                        } else if newValue.count > 1 {
                            let lastChar = newValue.last!
                            if lastChar.isNumber {
                                viewModel.insert(String(lastChar), type: .number)
                            } else if lastChar.isLetter {
                                viewModel.insert(String(lastChar), type: .variable)
                            } else if ["+", "-", "=", "/", "*", "^", ".", "<", ">", "|"].contains(lastChar) {
                                let mappedChar = lastChar == "/" ? "÷" : (lastChar == "*" ? "×" : String(lastChar))
                                viewModel.insert(mappedChar, type: .operatorSymbol)
                            } else if ["(", ")", "[", "]", "{", "}"].contains(lastChar) {
                                viewModel.insert(String(lastChar), type: .structural)
                            } else if lastChar == "\n" {
                                viewModel.newLine()
                            }
                        }
                        
                        // Reset bridge safely to capture subsequent inputs
                        nativeInputString = " "
                    }
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            
                            #if os(macOS)
                            HoverInsertLineButton { viewModel.insertLine(at: 0) }
                            #else
                            Color.clear.frame(height: 16)
                            #endif
                            
                            ForEach(0..<viewModel.lines.count, id: \.self) { lineIndex in
                                MathLineView(
                                    viewModel: viewModel,
                                    tokens: viewModel.lines[lineIndex],
                                    isActive: lineIndex == viewModel.activeLineIndex,
                                    cursorIndex: lineIndex == viewModel.activeLineIndex ? viewModel.cursorIndex : nil,
                                    lineIndex: lineIndex,
                                    onCursorTap: { newIndex in
                                        withAnimation(.snappy) {
                                            viewModel.moveCursor(to: newIndex, on: lineIndex)
                                        }
                                    }
                                )
                                .id(lineIndex)
                                .onDrag {
                                    self.draggedLineIndex = lineIndex
                                    return NSItemProvider(object: String(lineIndex) as NSString)
                                }
                                .onDrop(of: [.plainText], delegate: LineDropDelegate(item: lineIndex, viewModel: viewModel, draggedItem: $draggedLineIndex))
                                
                                #if os(macOS)
                                HoverInsertLineButton { viewModel.insertLine(at: lineIndex + 1) }
                                #else
                                Color.clear.frame(height: 16)
                                #endif
                            }
                            
                            // Essential clearance padding to push the active line completely above the custom keypad
                            Color.clear.frame(height: 30).id("BottomClearance")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(DotGridBackground())
                    .focusable()
                    .focused($isCanvasFocused)
                    // Hardware Keyboard Intercepts
                    .onKeyPress(phases: [.down, .repeat]) { press in
                        if press.modifiers.contains(.command) {
                            if press.key == KeyEquivalent("c") {
                                viewModel.copyActiveLine()
                                return .handled
                            }
                            if press.key == KeyEquivalent("v") {
                                viewModel.pasteToActiveLine()
                                return .handled
                            }
                            if press.key == KeyEquivalent("z") {
                                viewModel.undo()
                                return .handled
                            }
                        }
                        
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
                            return .handled
                        }
                        
                        if let char = press.characters.first {
                            if char.isNumber {
                                viewModel.insert(String(char), type: .number)
                                return .handled
                            } else if char.isLetter {
                                viewModel.insert(String(char), type: .variable)
                                return .handled
                            } else if ["+", "-", "=", "/", "*", "^", ".", "<", ">", "|"].contains(char) {
                                let mappedChar = char == "/" ? "÷" : (char == "*" ? "×" : String(char))
                                viewModel.insert(mappedChar, type: .operatorSymbol)
                                return .handled
                            } else if ["(", ")", "[", "]", "{", "}"].contains(char) {
                                viewModel.insert(String(char), type: .structural)
                                return .handled
                            }
                        }
                        return .ignored
                    }
                    .onChange(of: viewModel.activeLineIndex) { _, newIndex in
                        withAnimation(.snappy) {
                            proxy.scrollTo("BottomClearance", anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.cursorIndex) { _, _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.snappy) {
                                proxy.scrollTo("BottomClearance", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isKeypadExpanded) { _, _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.snappy) {
                                proxy.scrollTo("BottomClearance", anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // Custom Keypad
            if showCustomKeypad {
                MathKeypadView(viewModel: viewModel, isExpanded: $isKeypadExpanded)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
        .onChange(of: isNativeKeyboardFocused) { _, isFocused in
            if isFocused {
                withAnimation(.snappy) { showCustomKeypad = false }
            }
        }
    }
}

// MARK: - Components

#if os(macOS)
struct HoverInsertLineButton: View {
    var action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            Color.clear.frame(height: 18)
            
            HStack(spacing: 8) {
                Divider().background(Color.teal).opacity(isHovered ? 1 : 0)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.teal)
                    .opacity(isHovered ? 1 : 0.08)
                Divider().background(Color.teal).opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, 20)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .onTapGesture {
            withAnimation(.snappy) { action() }
        }
    }
}
#endif

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

struct FlowLayout: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 4

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

// MARK: - Line Rendering

struct MathLineView: View {
    let viewModel: MathScratchpadViewModel
    let tokens: [MathToken]
    let isActive: Bool
    let cursorIndex: Int?
    let lineIndex: Int
    let onCursorTap: (Int) -> Void
    
    let emeraldAccent = Color(red: 0.15, green: 0.85, blue: 0.65)
    @Environment(\.colorScheme) var colorScheme
    
    @State private var tokenFrames: [Int: CGRect] = [:]
    @State private var selectedRange: ClosedRange<Int>? = nil
    @State private var dragStartIndex: Int? = nil
    @State private var showSelectionMenu: Bool = false
    
    private var renderedLatexString: String {
        tokens.map { token in
            var val = token.value
            let isSafe = token.type == .number || token.type == .variable || token.type == .operatorSymbol
            
            if isSafe {
                if token.isScratchedOff {
                    val = "\\cancel{\(val)}"
                }
                if let color = token.highlightColor {
                    let hex: String
                    switch color {
                    case "blue": hex = colorScheme == .dark ? "#73D1FF" : "#007AFF"
                    case "red": hex = colorScheme == .dark ? "#FF7373" : "#FF3B30"
                    case "green": hex = colorScheme == .dark ? "#73FFBA" : "#34C759"
                    case "orange": hex = "#FF9500"
                    case "purple": hex = colorScheme == .dark ? "#D98CFF" : "#AF52DE"
                    case "pink": hex = "#FF2D55"
                    default: hex = color
                    }
                    val = "\\textcolor{\(hex)}{\(val)}"
                }
            }
            return val
        }.joined()
    }
    
    private func playSelectionHaptic() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(isActive ? emeraldAccent : Color.clear)
                .frame(width: 4)
                .shadow(color: isActive ? emeraldAccent.opacity(0.5) : Color.clear, radius: 4, y: 0)
                .padding(.vertical, 6)
            
            if isActive {
                VStack(alignment: .leading, spacing: 12) {
                    let latexString = renderedLatexString
                    
                    LatexView(latex: "$$ \(latexString.isEmpty ? "\\phantom{A}" : latexString) $$")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                        .padding(.leading, 8)
                        .opacity(latexString.isEmpty ? 0 : 1)
                    
                    HStack(alignment: .top) {
                        FlowLayout(spacing: 0, lineSpacing: 8) {
                            Color.clear
                                .frame(width: 6, height: 20)
                                .contentShape(Rectangle())
                                .overlay(alignment: .trailing) {
                                    if cursorIndex == 0 { BlinkingCursor() }
                                }
                            
                            ForEach(0..<tokens.count, id: \.self) { i in
                                TokenView(token: tokens[i], isSelected: selectedRange?.contains(i) == true)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(key: TokenFramePreferenceKey.self, value: [i: geo.frame(in: .named("LineSpace\(lineIndex)"))])
                                        }
                                    )
                                    .overlay(alignment: .trailing) {
                                        if cursorIndex == i + 1 { BlinkingCursor() }
                                    }
                                    #if os(macOS)
                                    .onTapGesture(count: 2) {
                                        selectedRange = i...i
                                        showSelectionMenu = true
                                    }
                                    .onTapGesture(count: 1) {
                                        onCursorTap(i + 1)
                                    }
                                    #else
                                    .onTapGesture {
                                        onCursorTap(i + 1)
                                    }
                                    .onLongPressGesture(minimumDuration: 0.3) {
                                        selectedRange = i...i
                                        showSelectionMenu = true
                                        playSelectionHaptic()
                                    }
                                    #endif
                            }
                        }
                        .coordinateSpace(name: "LineSpace\(lineIndex)")
                        .onPreferenceChange(TokenFramePreferenceKey.self) { frames in
                            self.tokenFrames = frames
                        }
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 4, coordinateSpace: .named("LineSpace\(lineIndex)"))
                                .onChanged { value in
                                    if let idx = tokenIndex(at: value.location) {
                                        if dragStartIndex == nil { dragStartIndex = idx }
                                        let start = min(dragStartIndex!, idx)
                                        let end = max(dragStartIndex!, idx)
                                        if selectedRange != start...end {
                                            selectedRange = start...end
                                            playSelectionHaptic()
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    dragStartIndex = nil
                                    if selectedRange != nil {
                                        showSelectionMenu = true
                                    }
                                }
                        )
                        .onTapGesture(coordinateSpace: .named("LineSpace\(lineIndex)")) { location in
                            selectedRange = nil
                            if let idx = tokenIndex(at: location) {
                                onCursorTap(idx + 1)
                            } else {
                                onCursorTap(tokens.count)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                        )
                        .popover(isPresented: $showSelectionMenu, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                            formattingPopoverContent
                        }
                        
                        Spacer(minLength: 8)
                        
                        if let result = viewModel.calculateCurrentLine() {
                            Text("= \(result)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(emeraldAccent.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: emeraldAccent.opacity(0.3), radius: 8, y: 4)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 16)
                    .padding(.trailing, 12)
                }
            } else {
                let latexString = renderedLatexString
                
                if latexString.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.app.dashed")
                            .font(.system(size: 16))
                        Text("Tap to write equation...")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.secondary.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .padding(.leading, 14)
                    .contentShape(Rectangle())
                    .onTapGesture { onCursorTap(tokens.count) }
                } else {
                    LatexView(latex: "$$ \(latexString) $$")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.leading, 14)
                        .contentShape(Rectangle())
                        .onTapGesture { onCursorTap(tokens.count) }
                }
            }
        }
        .frame(minHeight: 50)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isActive ? (colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.015)) : Color.clear)
        )
        .contextMenu {
            Button(action: { viewModel.copyLine(at: lineIndex) }) { Label("Copy Equation", systemImage: "doc.on.doc") }
            Button(action: { viewModel.pasteToLine(at: lineIndex) }) { Label("Paste Equation", systemImage: "doc.on.clipboard") }
        }
    }
    
    // MARK: - Popover
    private var formattingPopoverContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if selectedRange != nil {
                HStack(spacing: 16) {
                    
                    // Convert to fraction (a/b)
                    Button {
                        viewModel.convertToFraction(range: selectedRange!, on: lineIndex)
                        closeMenu()
                    } label: {
                        Text("a/b")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15), in: .rect(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    
                    Divider().frame(height: 20)
                    
                    Button {
                        viewModel.applyScratchOff(to: selectedRange!, on: lineIndex)
                        closeMenu()
                    } label: {
                        Image(systemName: "strikethrough")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    
                    Divider().frame(height: 20)
                    
                    ForEach(["blue", "red", "green", "orange", "purple", "pink"], id: \.self) { c in
                        Button { applyColor(c) } label: {
                            Circle()
                                .fill(colorForString(c))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button { applyColor(nil) } label: {
                        Image(systemName: "slash.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Divider()
            }
            
            Button(action: { viewModel.copyLine(at: lineIndex); closeMenu() }) {
                Label("Copy Equation", systemImage: "doc.on.doc")
            }
            .buttonStyle(.plain)
            
            Button(action: { viewModel.pasteToLine(at: lineIndex); closeMenu() }) {
                Label("Paste Equation", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .presentationCompactAdaptation(.popover)
    }
    
    // MARK: - Helpers
    private func closeMenu() {
        showSelectionMenu = false
        selectedRange = nil
    }
    
    private func applyColor(_ color: String?) {
        if let range = selectedRange {
            viewModel.applyHighlight(to: range, on: lineIndex, color: color)
            closeMenu()
        }
    }
    
    private func colorForString(_ colorString: String) -> Color {
        switch colorString {
        case "blue": return colorScheme == .dark ? Color(red: 0.45, green: 0.82, blue: 1.0) : .blue
        case "red": return colorScheme == .dark ? Color(red: 1.0, green: 0.45, blue: 0.45) : .red
        case "green": return colorScheme == .dark ? Color(red: 0.45, green: 1.0, blue: 0.65) : .green
        case "orange": return .orange
        case "purple": return colorScheme == .dark ? Color(red: 0.85, green: 0.55, blue: 1.0) : .purple
        case "pink": return .pink
        default: return .clear
        }
    }
    
    private func tokenIndex(at point: CGPoint) -> Int? {
        for (index, frame) in tokenFrames {
            if frame.contains(point) { return index }
        }
        
        var closestIndex: Int? = nil
        var minDistance: CGFloat = .infinity
        
        for (index, frame) in tokenFrames {
            let verticalBounds = frame.insetBy(dx: 0, dy: -20)
            if verticalBounds.contains(CGPoint(x: frame.midX, y: point.y)) {
                let distance = abs(frame.midX - point.x)
                if distance < minDistance && distance < 40 {
                    minDistance = distance
                    closestIndex = index
                }
            }
        }
        return closestIndex
    }
}

struct BlinkingCursor: View {
    @State private var isBlinking = false
    let emeraldAccent = Color(red: 0.15, green: 0.85, blue: 0.65)
    
    var body: some View {
        Capsule()
            .fill(emeraldAccent)
            .frame(width: 2.5, height: 18)
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
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var displayValue: String {
        let val = token.value
        switch val {
        case "\\lim_{x \\to ": return "lim x→"
        case "\\frac{d}{dx}[": return "d/dx ["
        case "\\sum_{": return "∑_"
        case "\\log_{10}(": return "log₁₀("
        case "\\sqrt{": return "√("
        case "\\frac{": return "frac("
        case "^{\\circ}": return "°"
        case "^{": return "^("
        case "_{": return "_("
        case "\\pi": return "π"
        case "\\theta": return "θ"
        case "\\alpha": return "α"
        case "\\beta": return "β"
        case "\\infty": return "∞"
        case "\\int": return "∫"
        case "\\to": return "→"
        case "\\lim": return "lim"
        case "\\sin": return "sin"
        case "\\cos": return "cos"
        case "\\tan": return "tan"
        case "\\ln": return "ln"
        case "\\log": return "log"
        case "\\sum": return "∑"
        case "\\sqrt": return "√"
        case "\\frac": return "frac"
        case "{": return "("
        case "}": return ")"
        case "\\{": return "{"
        case "\\}": return "}"
        default:
            return val.replacingOccurrences(of: "\\", with: "")
        }
    }
    
    var body: some View {
        Text(displayValue)
            .font(.system(size: 17, weight: weightForType(token.type), design: .rounded))
            .italic(token.type == .variable)
            .foregroundStyle(resolvedColor)
            .padding(.horizontal, paddingForType(token.type))
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.blue.opacity(colorScheme == .dark ? 0.4 : 0.2))
                    } else if token.highlightColor != nil {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(resolvedColor.opacity(0.15))
                    }
                }
            )
            .overlay {
                if token.isScratchedOff {
                    GeometryReader { geo in
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: geo.size.height))
                            p.addLine(to: CGPoint(x: geo.size.width, y: 0))
                        }
                        .stroke(colorScheme == .dark ? Color(red: 1.0, green: 0.35, blue: 0.35) : Color.red, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                }
            }
            .contentShape(Rectangle())
    }
    
    private var resolvedColor: Color {
        if let hc = token.highlightColor {
            switch hc {
            case "blue": return colorScheme == .dark ? Color(red: 0.45, green: 0.82, blue: 1.0) : .blue
            case "red": return colorScheme == .dark ? Color(red: 1.0, green: 0.45, blue: 0.45) : .red
            case "green": return colorScheme == .dark ? Color(red: 0.45, green: 1.0, blue: 0.65) : .green
            case "orange": return .orange
            case "purple": return colorScheme == .dark ? Color(red: 0.85, green: 0.55, blue: 1.0) : .purple
            case "pink": return .pink
            default: break
            }
        }
        return colorForType(token.type)
    }
    
    private func paddingForType(_ type: TokenType) -> CGFloat {
        switch type {
        case .operatorSymbol, .structural: return 2
        case .function: return 2
        case .number, .variable: return 0.5
        }
    }
    
    private func weightForType(_ type: TokenType) -> Font.Weight {
        switch type {
        case .operatorSymbol: return .heavy
        case .number, .variable: return .semibold
        default: return .bold
        }
    }
    
    private func colorForType(_ type: TokenType) -> Color {
        switch type {
        case .number: return .primary
        case .variable: return colorScheme == .dark ? Color(red: 0.45, green: 0.82, blue: 1.0) : Color.blue
        case .operatorSymbol: return Color(red: 1.0, green: 0.60, blue: 0.15)
        case .function: return colorScheme == .dark ? Color(red: 0.85, green: 0.55, blue: 1.0) : Color.purple
        case .structural: return .secondary.opacity(0.6)
        }
    }
}

// MARK: - Keypad

struct MathKeypadView: View {
    @Bindable var viewModel: MathScratchpadViewModel
    @Binding var isExpanded: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        isExpanded.toggle()
                        playHaptic()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(isExpanded ? Color.orange : Color.blue)
                        .frame(width: 40, height: 40)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(KeypadPressStyle())
                
                KeypadButton(icon: "arrow.left", style: .action) {
                    viewModel.moveCursorLeft()
                    playHaptic()
                }
                .frame(width: 40)
                
                KeypadButton(icon: "arrow.right", style: .action) {
                    viewModel.moveCursorRight()
                    playHaptic()
                }
                .frame(width: 40)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["x", "y", "θ", "π", "e"], id: \.self) { variable in
                            let isFunc = variable == "π" || variable == "e"
                            let val = variable == "π" ? "\\pi" : variable
                            KeypadButton(text: variable, type: isFunc ? .function : .variable, style: .variable) {
                                viewModel.insert(val, type: isFunc ? .function : .variable)
                                playHaptic()
                            }
                            .frame(width: 42)
                        }
                        
                        Divider().frame(height: 20)
                        
                        ForEach(["sin", "cos", "tan", "ln", "log"], id: \.self) { fn in
                            KeypadButton(text: fn, type: .function, style: .function) {
                                if fn == "log" { viewModel.insert("\\log_{10}(", type: .function) }
                                else { viewModel.insert("\\\(fn)(", type: .function) }
                                viewModel.insert(")", type: .structural)
                                viewModel.moveCursorLeft()
                                playHaptic()
                            }
                            .frame(width: 48)
                        }
                        
                        Divider().frame(height: 20)
                        
                        KeypadButton(text: "lim", type: .function, style: .function) {
                            viewModel.insert("\\lim_{x \\to ", type: .function)
                            viewModel.insert("}", type: .structural)
                            viewModel.insert("(", type: .structural)
                            viewModel.insert(")", type: .structural)
                            viewModel.moveCursorLeft()
                            viewModel.moveCursorLeft()
                            viewModel.moveCursorLeft()
                            playHaptic()
                        }
                        .frame(width: 50)
                        
                        KeypadButton(text: "d/dx", type: .function, style: .function) {
                            viewModel.insert("\\frac{d}{dx}[", type: .function)
                            viewModel.insert("]", type: .structural)
                            viewModel.moveCursorLeft()
                            playHaptic()
                        }
                        .frame(width: 52)
                        
                        KeypadButton(text: "∑", type: .function, style: .function) {
                            viewModel.insert("\\sum_{", type: .function)
                            viewModel.insert("}", type: .structural)
                            viewModel.insert("^{", type: .structural)
                            viewModel.insert("}", type: .structural)
                            viewModel.moveCursorLeft()
                            viewModel.moveCursorLeft()
                            viewModel.moveCursorLeft()
                            playHaptic()
                        }
                        .frame(width: 44)
                        
                        KeypadButton(text: "|x|", type: .function, style: .function) {
                            viewModel.insert("|", type: .structural)
                            viewModel.insert("|", type: .structural)
                            viewModel.moveCursorLeft()
                            playHaptic()
                        }
                        .frame(width: 44)
                        
                        KeypadButton(text: "√", type: .function, style: .function) {
                            viewModel.insert("\\sqrt{", type: .function)
                            viewModel.insert("}", type: .structural)
                            viewModel.moveCursorLeft()
                            playHaptic()
                        }
                        .frame(width: 44)
                    }
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                if isExpanded {
                    GridRow {
                        KeypadButton(text: "a/b", type: .function, style: .action) {
                            viewModel.insert("\\frac{", type: .function)
                            viewModel.insert("}", type: .structural)
                            viewModel.insert("{", type: .structural)
                            viewModel.insert("}", type: .structural)
                            viewModel.moveCursorLeft()
                            viewModel.moveCursorLeft()
                            viewModel.moveCursorLeft()
                            playHaptic()
                        }
                        KeypadButton(text: "(", type: .structural, style: .operator) { viewModel.insert("(", type: .structural); playHaptic() }
                        KeypadButton(text: ")", type: .structural, style: .operator) { viewModel.insert(")", type: .structural); playHaptic() }
                        KeypadButton(text: "[", type: .structural, style: .operator) { viewModel.insert("[", type: .structural); playHaptic() }
                        KeypadButton(text: "]", type: .structural, style: .operator) { viewModel.insert("]", type: .structural); playHaptic() }
                    }
                    GridRow {
                        KeypadButton(text: "{", type: .structural, style: .operator) { viewModel.insert("\\{", type: .structural); playHaptic() }
                        KeypadButton(text: "}", type: .structural, style: .operator) { viewModel.insert("\\}", type: .structural); playHaptic() }
                        KeypadButton(text: "∫", type: .function, style: .operator) { viewModel.insert("\\int", type: .function); playHaptic() }
                        KeypadButton(text: "∞", type: .number, style: .operator) { viewModel.insert("\\infty", type: .number); playHaptic() }
                        KeypadButton(text: "°", type: .operatorSymbol, style: .operator) { viewModel.insert("^{\\circ}", type: .operatorSymbol); playHaptic() }
                    }
                }
                
                GridRow {
                    KeypadButton(text: "7", style: .number) { viewModel.insert("7", type: .number); playHaptic() }
                    KeypadButton(text: "8", style: .number) { viewModel.insert("8", type: .number); playHaptic() }
                    KeypadButton(text: "9", style: .number) { viewModel.insert("9", type: .number); playHaptic() }
                    KeypadButton(text: "÷", type: .operatorSymbol, style: .operator) { viewModel.insert("÷", type: .operatorSymbol); playHaptic() }
                    KeypadButton(icon: "delete.left.fill", style: .destructive) { viewModel.backspace(); playHaptic() }
                }
                GridRow {
                    KeypadButton(text: "4", style: .number) { viewModel.insert("4", type: .number); playHaptic() }
                    KeypadButton(text: "5", style: .number) { viewModel.insert("5", type: .number); playHaptic() }
                    KeypadButton(text: "6", style: .number) { viewModel.insert("6", type: .number); playHaptic() }
                    KeypadButton(text: "×", type: .operatorSymbol, style: .operator) { viewModel.insert("×", type: .operatorSymbol); playHaptic() }
                    KeypadButton(text: "^", type: .operatorSymbol, style: .operator) { viewModel.insert("^", type: .operatorSymbol); playHaptic() }
                }
                GridRow {
                    KeypadButton(text: "1", style: .number) { viewModel.insert("1", type: .number); playHaptic() }
                    KeypadButton(text: "2", style: .number) { viewModel.insert("2", type: .number); playHaptic() }
                    KeypadButton(text: "3", style: .number) { viewModel.insert("3", type: .number); playHaptic() }
                    KeypadButton(text: "-", type: .operatorSymbol, style: .operator) { viewModel.insert("-", type: .operatorSymbol); playHaptic() }
                    KeypadButton(text: "=", type: .operatorSymbol, style: .action) { viewModel.insert("=", type: .operatorSymbol); playHaptic() }
                }
                GridRow {
                    KeypadButton(text: ".", style: .number) { viewModel.insert(".", type: .number); playHaptic() }
                    KeypadButton(text: "0", style: .number) { viewModel.insert("0", type: .number); playHaptic() }
                    KeypadButton(text: "( )", type: .structural, style: .operator) {
                        viewModel.insert("(", type: .structural)
                        viewModel.insert(")", type: .structural)
                        viewModel.moveCursorLeft()
                        playHaptic()
                    }
                    KeypadButton(text: "+", type: .operatorSymbol, style: .operator) { viewModel.insert("+", type: .operatorSymbol); playHaptic() }
                    KeypadButton(icon: "return", style: .confirm) { viewModel.newLine(); playHaptic() }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.12, green: 0.13, blue: 0.15) : Color(white: 0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
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
    }
    
    private func playHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
        #endif
    }
}

enum KeypadButtonStyleType {
    case number, `operator`, action, confirm, destructive, variable, function
}

struct KeypadButton: View {
    var text: String? = nil
    var icon: String? = nil
    var type: TokenType = .number
    var style: KeypadButtonStyleType
    var shortcut: KeyboardShortcut? = nil
    var action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(backgroundColor)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: style == .confirm ? 6 : 2, y: style == .confirm ? 4 : 1)
                
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
            // Compact 44pt height completely eliminates sheet overflow clipping
            .frame(height: 44)
        }
        .buttonStyle(KeypadPressStyle())
        .keyboardShortcut(shortcut)
    }
    
    private var backgroundColor: AnyShapeStyle {
        switch style {
        case .number:
            return AnyShapeStyle(colorScheme == .dark ? Color(white: 0.20) : Color.white)
        case .operator:
            return AnyShapeStyle(colorScheme == .dark ? Color(red: 1.0, green: 0.6, blue: 0.15).opacity(0.2) : Color(red: 1.0, green: 0.6, blue: 0.15).opacity(0.12))
        case .action:
            return AnyShapeStyle(colorScheme == .dark ? Color.blue.opacity(0.2) : Color.blue.opacity(0.12))
        case .confirm:
            return AnyShapeStyle(LinearGradient(colors: [Color(red: 0.15, green: 0.85, blue: 0.65), Color(red: 0.10, green: 0.70, blue: 0.50)], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .destructive:
            return AnyShapeStyle(colorScheme == .dark ? Color.red.opacity(0.25) : Color.red.opacity(0.12))
        case .variable:
            return AnyShapeStyle(colorScheme == .dark ? Color(white: 0.16) : Color(white: 0.96))
        case .function:
            return AnyShapeStyle(colorScheme == .dark ? Color.purple.opacity(0.15) : Color.purple.opacity(0.08))
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

// MARK: - Selection Tracking
struct TokenFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}
