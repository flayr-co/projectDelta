//
//  LessonView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseCore

struct LessonView: View {
    var subjectName: String
    @Environment(LessonViewModel.self) var lessonVM
    @Environment(AuthViewModel.self) var authVM

    @State private var showTableOfContents = false
    @State private var isInteractingWithExplanation: Bool = false
    @State private var showUIControls = true
    @State private var lastContentOffset: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    let warmTan = Color(red: 0.96, green: 0.94, blue: 0.90)
    let emeraldAccent = Color(red: 0.18, green: 0.80, blue: 0.44)

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.15) : warmTan)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if showUIControls {
                    headerView
                        .transition(.opacity)
                }

                if lessonVM.isLoading {
                    Spacer()
                    ProgressView("Loading lesson content...")
                        .tint(emeraldAccent)
                    Spacer()
                } else if lessonVM.lessonPages.isEmpty {
                    Spacer()
                    Text("No content available.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    // CRITICAL FIX: Zipped index mapping explicitly ties structural identity to the object, preserving TabView state
                    TabView(selection: Bindable(lessonVM).currentPageIndex) {
                        ForEach(Array(zip(lessonVM.lessonPages.indices, lessonVM.lessonPages)), id: \.1.id) { index, page in
                            LessonContentPage(
                                page: page,
                                isInteractingWithExplanation: $isInteractingWithExplanation,
                                onBackgroundTap: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        showUIControls.toggle()
                                    }
                                }
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .id(lessonVM.currentLessonId)
                    .onChange(of: lessonVM.currentPageIndex) { oldValue, newPageIndex in
                        if lessonVM.lessonPages.indices.contains(newPageIndex) {
                            let newPageNumber = lessonVM.lessonPages[newPageIndex].pageNumber
                            lessonVM.navigateToPage(lessonName: lessonVM.currentLessonName, pageNumber: newPageNumber, authVM: authVM)
                        }
                    }
                }
            }
            
            if showTableOfContents {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showTableOfContents = false
                        }
                    }
                
                TableOfContentsView(lessonVM: lessonVM, subjectName: subjectName, isShowing: $showTableOfContents)
                    .frame(width: 320)
                    .background(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.15) : warmTan)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.2), radius: 10)
                    .transition(.move(edge: .trailing))
                    .padding(.trailing, 16)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .overlay(alignment: .bottom) {
            if !lessonVM.isLoading && !lessonVM.lessonPages.isEmpty && showUIControls {
                lessonNavigationControls
                    .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // Task fires once per load; safe to trigger init logic here
            lessonVM.subjectName = subjectName
            await lessonVM.initializeLesson(subjectName: subjectName, authVM: authVM)
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(lessonVM.currentLessonName)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.leading)
                .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 16) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showTableOfContents.toggle()
                        if showTableOfContents {
                            lessonVM.fetchAllLessons(for: subjectName)
                        }
                    }
                }) {
                    Image(systemName: "list.number")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(emeraldAccent)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: {
                    lessonVM.toggleBookmark(authVM: authVM)
                }) {
                    Image(systemName: lessonVM.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18))
                        .foregroundColor(lessonVM.isCurrentPageBookmarked ? emeraldAccent : .secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.15) : warmTan)
    }

    private var lessonNavigationControls: some View {
        VStack {
            if lessonVM.currentPageIndex >= lessonVM.lessonPages.count - 1 {
                NavigationLink(destination: TestView(subject: subjectName)) {
                    Text("Take Quiz")
                        .font(.headline)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(emeraldAccent)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 25)
                .padding(.bottom, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            HStack {
                Button(action: {
                    withAnimation {
                        lessonVM.currentPageIndex = max(lessonVM.currentPageIndex - 1, 0)
                    }
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(emeraldAccent)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(lessonVM.currentPageIndex == 0)
                .opacity(lessonVM.currentPageIndex == 0 ? 0.3 : 1)

                Spacer()
                
                Text("\(lessonVM.currentPageIndex + 1) of \(lessonVM.lessonPages.count)")
                    .font(.footnote.monospacedDigit())
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

                Spacer()
                
                Button(action: {
                    withAnimation {
                        lessonVM.currentPageIndex = min(lessonVM.currentPageIndex + 1, lessonVM.lessonPages.count - 1)
                    }
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(emeraldAccent)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(lessonVM.currentPageIndex == lessonVM.lessonPages.count - 1)
                .opacity(lessonVM.currentPageIndex == lessonVM.lessonPages.count - 1 ? 0.3 : 1)
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 30)
        }
    }
}

#Preview {
    LessonView(subjectName: "Algebra")
        .environment(LessonViewModel())
        .environment(AuthViewModel())
}
