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
    @ObservedObject var lessonVM: LessonViewModel
//    @State private var currentPageIndex = 0    NO LONGER NEEDED, USE PUBLISHED VARIABLE
    @State private var currentLessonName: String = ""
    @State private var showTableOfContents = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack {
            if lessonVM.lessonPages.isEmpty {
                Text("Loading lesson content...")
                    .onAppear {
                        lessonVM.fetchFirstIncompleteLesson(for: subjectName) { lessonName in
                            self.currentLessonName = lessonName
                            lessonVM.fetchLessonContent(for: subjectName, lessonName: currentLessonName)
                        }
                    }
            } else {
                Button(action: {
                   // Toggle without animation to see if it helps with the double tap issue
                   self.showTableOfContents.toggle()
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
                                explanation: lessonVM.lessonPages[index].explanation
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
        }
        .navigationBarTitle("Lesson on \(subjectName)", displayMode: .inline)
        .onAppear {
            lessonVM.fetchAllLessons(for: subjectName)
            lessonVM.fetchLessonContent(for: lessonVM.subjectName, lessonName: currentLessonName)
        }
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
                
                Text(text.replacingOccurrences(of: "\\n", with: "\n"))
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .minimumScaleFactor(0.5) // Down to 50% of the original size
                    .lineLimit(nil) // Unlimited line limit
                    .padding(.horizontal)

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
                                 .renderingMode(.template) // Makes the image a template image
                                 .colorMultiply(colorScheme == .dark ? .cyan : .black)
                                 .scaledToFit()
                                 .frame(maxWidth: UIScreen.main.bounds.width - 260)
                                 .padding(.vertical, 20) // Add some spacing after the image
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
        Text(processedText)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .padding(.horizontal)
    }
}

#Preview {
    LessonView(subjectName: "Geometry", lessonVM: LessonViewModel(subjectName: "Geometry"))
        .preferredColorScheme(.dark)
}
