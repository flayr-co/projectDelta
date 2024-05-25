//
//  LessonView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 10/31/23.
//

// LessonView.swift
import SwiftUI
import Firebase

struct LessonView: View {
    var subjectName: String
    @EnvironmentObject var lessonVM: LessonViewModel
    @EnvironmentObject var authVM: AuthViewModel

    @State private var showTableOfContents = false
    @State private var isInteractingWithExplanation: Bool = false
    @State private var showHeader = true
    @State private var lastContentOffset: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            HStack(spacing: 16) {
                BackButtonView {
                    presentationMode.wrappedValue.dismiss()
                }
                
                Text("\(lessonVM.currentLessonName)")
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Spacer()
                
                // Table of Contents Button
                Button(action: {
                    showTableOfContents.toggle()
                    if showTableOfContents {
                        lessonVM.fetchAllLessons(for: subjectName)
                    }
                }) {
                    Image(systemName: "list.number")
                        .accessibility(label: Text("Show Table of Contents"))
                        .foregroundStyle(colorScheme == .dark ? .mint : .accentColor)
                }
                .padding()
                .background(showTableOfContents ? Color.gray.opacity(0.2) : Color.clear)
                .cornerRadius(8)

                // Bookmark button
                Button(action: {
                    lessonVM.toggleBookmark(authVM: authVM)
                }) {
                    let isBookmarked = lessonVM.isCurrentPageBookmarked
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundColor(isBookmarked ? Color.accentColor : Color.secondary)
                }
                .padding(.vertical)
                .padding(.horizontal)
            }
            .padding(.top, 16)  // Adjust the padding to ensure it's visible at the top
            .transition(.move(edge: .top))
            .animation(.default, value: showHeader)
            
            if lessonVM.lessonPages.isEmpty {
                Text("Loading lesson content...")
            } else {
                if showTableOfContents {
                    TableOfContentsView(lessonVM: lessonVM, subjectName: subjectName)
                        .frame(width: 300)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }

                ScrollViewReader { proxy in
                    TabView(selection: $lessonVM.currentPageIndex) {
                        ForEach(lessonVM.lessonPages.indices, id: \.self) { index in
                            LessonContentPage(
                                text: lessonVM.lessonPages[index].content,
                                exampleText: lessonVM.lessonPages[index].example,
                                graphicsURL: lessonVM.lessonPages[index].graphics,
                                explanation: lessonVM.lessonPages[index].explanation,
                                graphData: lessonVM.lessonPages[index].graphData,  // Ensure graphData is passed
                                readyButtonDisplayed: lessonVM.lessonPages[index].readyButtonDisplayed,
                                isInteractingWithExplanation: $isInteractingWithExplanation
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(maxHeight: .infinity)
                    .onChange(of: lessonVM.currentPageIndex) { newPageIndex in
                        if let newPageNumber = lessonVM.lessonPages[safe: newPageIndex]?.pageNumber {
                            lessonVM.navigateToPage(lessonName: lessonVM.currentLessonName, pageNumber: newPageNumber, authVM: authVM)
                        }
                    }
                }
                .background(GeometryReader { geo in
                    Color.clear.onChange(of: geo.frame(in: .global).minY) { value in
                        if value < lastContentOffset {
                            withAnimation {
                                showHeader = false
                            }
                        } else {
                            withAnimation {
                                showHeader = true
                            }
                        }
                        lastContentOffset = value
                    }
                })

                lessonNavigationControls
            }
        }
        .navigationBarHidden(true) // Hide the default navigation bar
        .onAppear {
            lessonVM.subjectName = subjectName  // Ensure subjectName is set
            Task {
                await lessonVM.initializeLesson(subjectName: subjectName, authVM: authVM)
            }
        }
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
        .overlay(lessonNavigationControls, alignment: .bottom)
    }

    @ViewBuilder
    private var lessonNavigationControls: some View {
        HStack {
            Button(action: {
                withAnimation {
                    lessonVM.currentPageIndex = max(lessonVM.currentPageIndex - 1, 0)
                }
            }) {
                Image(systemName: "chevron.left")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .padding(.leading, 20)
                    .foregroundStyle(colorScheme == .dark ? .mint : .accentColor)
            }
            Spacer()
            Text("\(lessonVM.currentPageIndex + 1) of \(lessonVM.lessonPages.count)")
                .foregroundColor(.gray)
            Spacer()
            Button(action: {
                withAnimation {
                    lessonVM.currentPageIndex = min(lessonVM.currentPageIndex + 1, lessonVM.lessonPages.count - 1)
                }
            }) {
                Image(systemName: "chevron.right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .padding(.trailing, 20)
                    .foregroundStyle(colorScheme == .dark ? .mint : .accentColor)
            }
        }
        .padding(.bottom, 40)
    }
}

// MARK: - LessonContentPage
struct LessonContentPage: View {
    var text: String
    var exampleText: String?
    var graphicsURL: String?
    var explanation: String?
    var graphData: GraphData?
    var readyButtonDisplayed: Bool
    @Binding var isInteractingWithExplanation: Bool
    @State private var isExplanationVisible: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollViewContentHeight: CGFloat = 0
    @State private var showScrollIndicator: Bool = false
    @State private var timer: Timer?

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack {
                        Group {
                            if exampleText == nil && graphicsURL == nil && explanation == nil {
                                Spacer(minLength: geometry.size.height * 0.3)
                            } else {
                                Spacer(minLength: geometry.size.height * 0.03)
                            }
                        }
                        
                        TextStylingUtility.styledText(from: text)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .minimumScaleFactor(0.5)
                            .lineLimit(nil)
                            .padding(.horizontal)
                            .lineSpacing(10)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        // Graph display
                        if let graphData = graphData {
                            DynamicGraphView(data: graphData)
                                .padding(.bottom, exampleText == nil || exampleText!.isEmpty ? 0 : 15) // Conditional bottom padding
//                                .padding(.top, 80)
                                .padding(.top, exampleText == nil || exampleText!.isEmpty ? 80 : 58) // Conditional bottom padding
                                .frame(maxWidth: .infinity, alignment: .center)
                                .onAppear {
                                    print("Displaying graph data: \(graphData.xValues), \(graphData.yValues)")
                                }
                        }

                        if let example = exampleText, !example.isEmpty {
                            ExampleView(text: example)
                                .padding(.top, graphData == nil ? 40 : 5) // Conditional top padding
//                                .padding(.top, 40)
                                .padding(.bottom, 20)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .onAppear {
                                    print("ExampleView bottom padding: \(graphData == nil ? 20 : 0)")
                                }
                        }

                        // Explanation dropdown
                        if let explanationText = explanation, !explanationText.isEmpty {
                            Button {
                                withAnimation {
                                    isExplanationVisible.toggle()
                                    isInteractingWithExplanation = isExplanationVisible
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.seal.fill")
                                    Text("See explanation")
                                }
                            }
                            .foregroundColor(.HuluGreen)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                            
                            if isExplanationVisible {
                                ExampleView(text: explanationText)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }

                        // Ready button display
                        if readyButtonDisplayed {
                            VStack(spacing: 20) {
                                Button(action: {
                                    // Action for the ready button
                                }) {
                                    AnimatedActionButton()
                                        .padding()
                                }
                                .padding(.top, 20)
                                .frame(maxWidth: .infinity, alignment: .center)

                                NavigationLink {
                                    PracticeTestView()
                                } label: {
                                    Text("Go to test")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(colorScheme == .dark ? .cyan : .green)
                                }
                            }
                        }

                        Spacer()
                    }
                    .background(GeometryReader { proxy in
                        Color.clear.onAppear {
                            scrollViewContentHeight = proxy.size.height
                        }
                    })
                    .frame(minHeight: geometry.size.height)
                    .background(GeometryReader { proxy in
                        Color.clear.onAppear {
                            scrollViewContentHeight = proxy.size.height
                        }
                    })
                }
                .background(GeometryReader { proxy in
                    Color.clear.onAppear {
                        scrollViewContentHeight = proxy.size.height
                    }
                    .onChange(of: scrollOffset) { newValue in
                        print("Scroll offset changed: \(newValue)")
                    }
                })
                .overlay(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                scrollOffset = proxy.frame(in: .global).minY
                            }
                            .onChange(of: proxy.frame(in: .global).minY) { newValue in
                                scrollOffset = newValue
                                showScrollIndicator = true
                                timer?.invalidate()
                                timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
                                    withAnimation {
                                        showScrollIndicator = false
                                    }
                                }
                            }
                    }
                )
                .overlay(
                    VStack {
                        Spacer()
                        if showScrollIndicator && scrollOffset < scrollViewContentHeight - geometry.size.height - 20 {
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                                .padding()
                                .background(Circle().fill(Color.white).shadow(radius: 10))
                                .padding(.bottom, 30)
                                .transition(.opacity)
                                .animation(.easeInOut, value: scrollOffset)
                        }
                    }
                )
            }
        }
    }
}

struct ExampleView: View {
    var text: String
    @Environment(\.colorScheme) var colorScheme

    var parsedContent: [(String, String)] {
        text.split(separator: "\n").map { line in
            let parts = line.split(separator: "||", maxSplits: 1, omittingEmptySubsequences: false)
            let example = String(parts[0])
            let explanation = parts.count > 1 ? String(parts[1]) : ""
            return (example, explanation)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                ForEach(parsedContent, id: \.0) { (example, explanation) in
                    if example.contains("$$") {
                        let latex = example.replacingOccurrences(of: "$$", with: "")
                        VStack {
                            LatexView(latex: String("$$\(latex)$$"))
                                .frame(minHeight: latex.contains("\\frac") ? 75 : 50) // Adjust height if contains \frac
                                .padding(4) // Adjust the padding as needed
                                .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                                .cornerRadius(10)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(colorScheme == .dark ? Color.black : Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    } else {
                        GeometryReader { geometry in
                            VStack {
                                let formattedText = self.formatText(example)
                                formattedText
                                    .padding(8) // Adjust the padding as needed
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                    .background(colorScheme == .dark ? Color.black : Color.white)
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                                    .lineSpacing(10)
                            }
                            .frame(height: geometry.size.height)
                        }
                        .frame(minHeight: 50)
                    }

                    if !explanation.isEmpty {
                        Text(explanation)
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .padding(.bottom, 10) // Add top padding to create space between example and explanation
                    }
                }
            }
        }
    }

    func formatText(_ line: String) -> Text {
        let regex = try! NSRegularExpression(pattern: "\\*blue (.*?) blue\\*", options: [])
        let nsString = line as NSString
        let results = regex.matches(in: line, options: [], range: NSRange(location: 0, length: nsString.length))

        var formattedText = Text("")

        var lastIndex = 0
        for result in results {
            let range = result.range(at: 1)
            let beforeText = nsString.substring(with: NSRange(location: lastIndex, length: result.range.location - lastIndex))
            formattedText = formattedText + Text(beforeText)
            let blueText = nsString.substring(with: range)
            formattedText = formattedText + Text(blueText).foregroundColor(Color.blue)
            lastIndex = result.range.location + result.range.length
        }

        if lastIndex < nsString.length {
            let remainingText = nsString.substring(from: lastIndex)
            formattedText = formattedText + Text(remainingText)
        }

        return formattedText
    }
}

struct ScrollOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ViewHeightKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension NSRegularExpression {
    func split(_ string: String, range: NSRange) -> [(text: String, separator: String)] {
        var results = [(text: String, separator: String)]()
        let matches = self.matches(in: string, options: [], range: range)
        var lastEnd = range.lowerBound

        for match in matches {
            let textRange = NSRange(lastEnd..<match.range.lowerBound)
            if let textRange = Range(textRange, in: string) {
                let text = String(string[textRange])
                let separator = (string as NSString).substring(with: match.range)
                results.append((text, separator))
            }
            lastEnd = match.range.upperBound
        }

        if lastEnd < range.upperBound, let remainingRange = Range(NSRange(lastEnd..<range.upperBound), in: string) {
            results.append((String(string[remainingRange]), ""))
        }

        return results
    }
}

#Preview {
    LessonView(subjectName: "Algebra")
        .environmentObject(LessonViewModel())
        .environmentObject(AuthViewModel())
        .preferredColorScheme(.dark)
}
