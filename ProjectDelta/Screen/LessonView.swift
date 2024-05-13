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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack {
            if lessonVM.lessonPages.isEmpty {
                Text("Loading lesson content...")
            } else {
                HStack {
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

                    Button(action: {
                        print("bookmark button pressed...")
                        print("Current Subject: \(subjectName)")
                        lessonVM.toggleBookmark(authVM: authVM)
                        print("Bookmark status after toggle: \(lessonVM.isCurrentPageBookmarked)")
                    }) {
                        let isBookmarked = lessonVM.isCurrentPageBookmarked
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundColor(isBookmarked ? Color.accentColor : Color.secondary)
                    }
                    .padding()
                }

                if showTableOfContents {
                    TableOfContentsView(lessonVM: lessonVM, subjectName: subjectName)
                        .frame(width: 300)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }

                TabView(selection: $lessonVM.currentPageIndex) {
                    ForEach(lessonVM.lessonPages.indices, id: \.self) { index in
                        VStack {
                            LessonContentPage(
                                text: lessonVM.lessonPages[index].content,
                                exampleText: lessonVM.lessonPages[index].example,
                                graphicsURL: lessonVM.lessonPages[index].graphics,
                                explanation: lessonVM.lessonPages[index].explanation,
                                isInteractingWithExplanation: $isInteractingWithExplanation
                            )

                            if lessonVM.lessonPages[index].readyButtonDisplayed {
                                AnimatedActionButton()
                                    .padding(.bottom, UIScreen.main.bounds.height * 0.05)
                            }
                        }
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

                lessonNavigationControls
            }
        }
        .navigationBarTitle("Lesson on \(lessonVM.currentLessonName)", displayMode: .inline)
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

struct LessonContentPage: View {
    var text: String
    var exampleText: String?
    var graphicsURL: String?
    var explanation: String?
    @Binding var isInteractingWithExplanation: Bool  // Bind this state from parent view
    @State private var isExplanationVisible: Bool = false // State to track visibility
    
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Group {
                    if exampleText == nil && graphicsURL == nil && explanation == nil {
                        Spacer(minLength: geometry.size.height * 0.3) // Larger space for content-only pages
                    } else {
                        Spacer(minLength: geometry.size.height * 0.1) // Reduced space for pages with additional elements
                    }
                }
                
                TextStylingUtility.styledText(from: text)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .minimumScaleFactor(0.5)
                    .lineLimit(nil)
                    .padding(.horizontal)
                    .lineSpacing(10)

                if let example = exampleText, !example.isEmpty {
                    ExampleView(text: example)
                        .padding(.bottom, 20) // Add some spacing after the example
                        .padding(.top, 40)
                }
                
                // Load and display graphics if available
                if let urlString = graphicsURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable()
//                                 .renderingMode(.template) // Makes the image a template image
//                                 .colorMultiply(colorScheme == .dark ? .cyan : .black)
                                 .scaledToFit()
                                 .frame(maxWidth: UIScreen.main.bounds.width - 260)
                                 .padding(.vertical, 20) // Add some spacing after the image
                                 .clipShape(RoundedRectangle(cornerRadius: 10.0))
                        } else if phase.error != nil {
                            Text("Unable to load image")
                                .foregroundColor(.red)
                                .padding(.bottom, 30)
                        } else {
                            ProgressView()
                                .padding(.bottom, 20)
                        }
                    }
                }
                
                // Explanation dropdown
                if let explanationText = explanation, !explanationText.isEmpty {
                    Button{
                        withAnimation {
                            isExplanationVisible.toggle()
                            isInteractingWithExplanation = isExplanationVisible  // Update state based on visibility
                        }
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            
                            Text("See explanation")
                        }
                    }
                    .foregroundColor(.HuluGreen)
                    .padding()
                    
                    if isExplanationVisible {
                        ExampleView(text: explanationText)
                    }
                }
                
                Spacer() // This spacer will push all content towards the top, giving it a top-centered appearance
                
            } //: VSTACK
            .frame(minHeight: geometry.size.height) // This ensures the VStack takes up at least the full height of the GeometryReader
        }
    }
}

struct ExampleView: View {
    var text: String

    var processedText: String {
        text.replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\\n", with: "\n") // To handle both \n and \\n
    }

    var body: some View {
        TextStylingUtility.styledText(from: processedText)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .padding(.horizontal)
            .lineSpacing(10)
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
//        .preferredColorScheme(.dark)
}
