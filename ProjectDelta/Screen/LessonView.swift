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
//    @State private var currentPageIndex = 0    NO LONGER NEEDED, USE PUBLISHED VARIABLE
    @State private var currentLessonName: String = ""
    @State private var showTableOfContents = false
    @State private var isInteractingWithExplanation: Bool = false  // State to determine if interaction with explanation is ongoing
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack {
            if lessonVM.lessonPages.isEmpty {
                Text("Loading lesson content...")
            } else {
                Button(action: {
                    // Toggle without animation to see if it helps with the double tap issue
                    showTableOfContents.toggle()
                    if showTableOfContents {
                        // Fetch lessons when the table of contents is about to be shown
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
                
                if showTableOfContents {
                    TableOfContentsView(lessonVM: lessonVM, subjectName: subjectName)
                        .frame(width: 300) // Set a fixed width for the table of contents
                        .background(Color.white) // Optional: Set a background color
                        .cornerRadius(12) // Optional: Round the corners
                        .shadow(radius: 5) // Optional: Add a shadow for some depth
                }
                
                // MARK: - MAIN CONTENT HERE
                TabView(selection: $lessonVM.currentPageIndex) {
                    ForEach(lessonVM.lessonPages.indices, id: \.self) { index in
                        VStack {
                            LessonContentPage(
                                text: lessonVM.lessonPages[index].content,
                                exampleText: lessonVM.lessonPages[index].example,
                                graphicsURL: lessonVM.lessonPages[index].graphics,
                                explanation: lessonVM.lessonPages[index].explanation,
                                isInteractingWithExplanation: $isInteractingWithExplanation  // Pass the binding
                            )
                            
                            if lessonVM.lessonPages[index].readyButtonDisplayed {
                                AnimatedActionButton()
                                    .padding(.bottom, UIScreen.main.bounds.height * 0.05)
                            }
                        } //: VSTACK
                        .tag(index)
                    } //: FOREACH
                    
                } //: TABVIEW
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(maxHeight: .infinity) // Use maximum available height
                
                // Navigation controls
                lessonNavigationControls
            }
        } //: VSTACK
        .navigationBarTitle("Lesson on \(currentLessonName)", displayMode: .inline)
        .onAppear {
            Task {
                await initializeLesson()
            }
        }
        .background(colorScheme == .dark ? Color.customDarkGray : Color.white)
        .overlay(lessonNavigationControls, alignment: .bottom)
    } //: BODY
    
    private func goToNextPage() {
        withAnimation {
            lessonVM.currentPageIndex = min(lessonVM.currentPageIndex + 1, lessonVM.lessonPages.count - 1)
        }
    }

    private func initializeLesson() async {
        print("Starting to fetch the first incomplete lesson for \(subjectName).")
        let lessonName = await lessonVM.fetchFirstIncompleteLesson(for: subjectName)
        DispatchQueue.main.async {
            self.currentLessonName = lessonName
            print("First incomplete lesson fetched: \(lessonName)")
        }
        print("Starting to fetch lesson content for \(subjectName), lesson \(lessonName).")
        await lessonVM.fetchLessonContent(for: subjectName, lessonName: lessonName)
        print("Content fetching completed for lesson \(lessonName).")
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
        .padding(.bottom, 40) // Adjust padding as needed
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
        .environmentObject(LessonViewModel(subjectName: "Algebra"))
//        .preferredColorScheme(.dark)
}
