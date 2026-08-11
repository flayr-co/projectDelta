//
//  LessonView.swift
//  ProjectDelta
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct LessonView: View {
    var subjectName: String
    @Environment(LessonViewModel.self) var lessonVM
    @Environment(AuthViewModel.self) var authVM

    @State private var showTableOfContents = false
    @State private var isInteractingWithExplanation: Bool = false
    @State private var showUIControls = true
    @AppStorage("hideCustomTabBar") private var hideCustomTabBar: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @State private var hasQuiz: Bool = false

    var body: some View {
        Group {
            #if os(macOS)
            macOSLayout
            #else
            iOSLayout
            #endif
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        // Dynamically collapses the tab bar when UI controls are visible
        .toolbar(showUIControls ? .hidden : .visible, for: .tabBar)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showUIControls)
        #endif
        .onAppear { hideCustomTabBar = showUIControls }
        .onDisappear { hideCustomTabBar = false }
        .onChange(of: showUIControls) { _, isVisible in
            hideCustomTabBar = isVisible
        }
        .task {
            lessonVM.subjectName = subjectName
            await lessonVM.initializeLesson(subjectName: subjectName, authVM: authVM)
        }
        .task(id: lessonVM.currentLessonName) {
            await checkQuizStatus()
        }
    }

    private func checkQuizStatus() async {
        guard !lessonVM.currentLessonName.isEmpty else { return }
        let db = Firestore.firestore()
        do {
            let byIdSnap = try? await db.collection("Subjects").document(subjectName).collection("Tests")
                .whereField("subtopic", isEqualTo: lessonVM.currentLessonName).limit(to: 1).getDocuments()
            
            if let docs = byIdSnap?.documents, !docs.isEmpty {
                withAnimation { hasQuiz = true }
                return
            }
            
            let querySnap = try await db.collection("Subjects").whereField("name", isEqualTo: subjectName).getDocuments()
            for doc in querySnap.documents {
                let testsSnap = try await db.collection("Subjects").document(doc.documentID).collection("Tests")
                    .whereField("subtopic", isEqualTo: lessonVM.currentLessonName)
                    .limit(to: 1)
                    .getDocuments()
                if !testsSnap.documents.isEmpty {
                    withAnimation { hasQuiz = true }
                    return
                }
            }
            withAnimation { hasQuiz = false }
        } catch {
            print("Failed to check for quiz: \(error)")
        }
    }

    // MARK: - DESKTOP LAYOUT (macOS)
    #if os(macOS)
    private var macOSLayout: some View {
        ZStack(alignment: .top) {
            Color.platformSystemGroupedBackground.ignoresSafeArea()

            if lessonVM.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading curriculum...")
                        .controlSize(.large)
                        .tint(.teal)
                    Spacer()
                }
            } else if lessonVM.lessonPages.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "book.closed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No content available.")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ZStack(alignment: .bottom) {
                    ForEach(Array(lessonVM.lessonPages.enumerated()), id: \.element.id) { index, page in
                        LessonContentPage(
                            page: page,
                            isLastPage: index == lessonVM.lessonPages.count - 1,
                            isInteractingWithExplanation: $isInteractingWithExplanation,
                            onBackgroundTap: {}
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.platformSystemGroupedBackground)
                        .allowsHitTesting(lessonVM.currentPageIndex == index)
                        .opacity(lessonVM.currentPageIndex == index ? 1.0 : 0.01)
                        .zIndex(lessonVM.currentPageIndex == index ? 1 : 0)
                    }
                }
                .id(lessonVM.currentLessonId)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .top) {
                    if showUIControls { macOSHeaderView }
                }
                .safeAreaInset(edge: .bottom) {
                    if showUIControls { macOSNavigationControls }
                }
                .onChange(of: lessonVM.currentPageIndex) { oldValue, newPageIndex in
                    if lessonVM.lessonPages.indices.contains(newPageIndex) {
                        lessonVM.currentPageDocumentId = lessonVM.lessonPages[newPageIndex].id
                        lessonVM.updateBookmarkStatus(authVM: authVM)
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
                    .zIndex(4)

                TableOfContentsView(lessonVM: lessonVM, subjectName: subjectName, isShowing: $showTableOfContents)
                    .frame(width: 360)
                    .background(Color.platformSystemBackground)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.2), radius: 40, x: -10, y: 0)
                    .transition(.move(edge: .trailing))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .ignoresSafeArea(edges: .bottom)
                    .zIndex(5)
            }
        }
    }

    private var macOSHeaderView: some View {
        HStack(spacing: 16) {
            Button(action: { dismiss() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Exit")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(lessonVM.currentLessonName)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundColor(.primary)
                .shadow(color: colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05), radius: 2, y: 1)

            Spacer()

            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showTableOfContents.toggle()
                        if showTableOfContents { lessonVM.fetchAllLessons(for: subjectName) }
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle")
                        Text("Index")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: {
                    lessonVM.toggleBookmark(authVM: authVM)
                }) {
                    Image(systemName: lessonVM.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(lessonVM.isCurrentPageBookmarked ? .teal : .secondary)
                        .frame(width: 36, height: 36)
                        .background(lessonVM.isCurrentPageBookmarked ? Color.teal.opacity(0.15) : Color.primary.opacity(0.05))
                        .clipShape(Circle())
                        .shadow(color: lessonVM.isCurrentPageBookmarked ? Color.teal.opacity(0.3) : .clear, radius: 6, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private var macOSNavigationControls: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 24) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        lessonVM.currentPageIndex = max(lessonVM.currentPageIndex - 1, 0)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                        Text("Previous")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(lessonVM.currentPageIndex == 0 ? .gray.opacity(0.3) : .teal)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(lessonVM.currentPageIndex == 0)

                Spacer()

                Text("Page \(lessonVM.currentPageIndex + 1) of \(lessonVM.lessonPages.count)")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                    .foregroundColor(.secondary)

                Spacer()

                if lessonVM.currentPageIndex >= lessonVM.lessonPages.count - 1 && hasQuiz {
                    NavigationLink(destination: UniversalTestView(mode: .quick(subject: subjectName, subtopic: lessonVM.currentLessonName))) {
                        HStack(spacing: 8) {
                            Text("Assess Knowledge")
                            Image(systemName: "checkmark.seal.fill")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.teal)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.teal.opacity(0.4), radius: 12, y: 4)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            lessonVM.currentPageIndex = min(lessonVM.currentPageIndex + 1, lessonVM.lessonPages.count - 1)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text("Next")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(lessonVM.currentPageIndex == lessonVM.lessonPages.count - 1 ? .gray.opacity(0.3) : .teal)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(lessonVM.currentPageIndex == lessonVM.lessonPages.count - 1)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.05), radius: 8, y: -4)
        }
    }
    #endif

    // MARK: - MOBILE LAYOUT (iOS)
    #if os(iOS)
    private var iOSLayout: some View {
        ZStack {
            (colorScheme == ColorScheme.dark ? Color.customDarkGray : Color.platformSystemGroupedBackground)
                .ignoresSafeArea()
            
            if lessonVM.isLoading {
                ProgressView("Loading curriculum...")
                    .tint(.teal)
            } else if lessonVM.lessonPages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No content available.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            } else {
                // Stack pages to defeat WKWebView's aggressive iOS suspension algorithms
                ZStack {
                    ForEach(Array(lessonVM.lessonPages.enumerated()), id: \.element.id) { index, page in
                        LessonContentPage(
                            page: page,
                            isLastPage: index == lessonVM.lessonPages.count - 1,
                            isInteractingWithExplanation: $isInteractingWithExplanation,
                            onBackgroundTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showUIControls.toggle()
                                }
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(colorScheme == .dark ? Color.customDarkGray : Color.platformSystemGroupedBackground)
                        // An opaque overlay allows the underlying WKWebView to mathematically maintain 100% opacity without bleeding into the active page UI
                        .overlay(
                            Group {
                                if lessonVM.currentPageIndex != index {
                                    (colorScheme == .dark ? Color.customDarkGray : Color.platformSystemGroupedBackground)
                                        .ignoresSafeArea()
                                }
                            }
                        )
                        // Force 5% opacity threshold to bypass CoreAnimation occlusion culling completely
                        .opacity(lessonVM.currentPageIndex == index ? 1.0 : 0.05)
                        .allowsHitTesting(lessonVM.currentPageIndex == index)
                        .zIndex(lessonVM.currentPageIndex == index ? 1 : 0)
                    }
                }
                .id(lessonVM.currentLessonId)
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            
                            if value.translation.width < -40 && lessonVM.currentPageIndex < lessonVM.lessonPages.count - 1 {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    lessonVM.currentPageIndex += 1
                                }
                            } else if value.translation.width > 40 && lessonVM.currentPageIndex > 0 {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    lessonVM.currentPageIndex -= 1
                                }
                            }
                        }
                )
                .ignoresSafeArea(edges: .bottom)
                .safeAreaInset(edge: .top) {
                    if showUIControls && !lessonVM.isLoading {
                        headerView
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if !lessonVM.isLoading && !lessonVM.lessonPages.isEmpty && showUIControls {
                        lessonNavigationControls
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .onChange(of: lessonVM.currentPageIndex) { oldValue, newPageIndex in
                    if lessonVM.lessonPages.indices.contains(newPageIndex) {
                        lessonVM.currentPageDocumentId = lessonVM.lessonPages[newPageIndex].id
                        lessonVM.updateBookmarkStatus(authVM: authVM)
                    }
                }
            }
            
            if showTableOfContents {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showTableOfContents = false
                        }
                    }
                    .zIndex(2)
                
                TableOfContentsView(lessonVM: lessonVM, subjectName: subjectName, isShowing: $showTableOfContents)
                    .frame(width: 320)
                    .background(Color.platformSystemBackground)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.25), radius: 25, x: -5, y: 0)
                    .transition(.move(edge: .trailing))
                    .padding(.trailing, 16)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .zIndex(3)
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 40, height: 40)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text(lessonVM.currentLessonName)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showTableOfContents.toggle()
                        if showTableOfContents { lessonVM.fetchAllLessons(for: subjectName) }
                    }
                }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.teal)
                        .frame(width: 40, height: 40)
                        .background(Color.teal.opacity(0.15))
                        .clipShape(Circle())
                        .shadow(color: Color.teal.opacity(0.2), radius: 6, y: 2)
                }
                .buttonStyle(.plain)

                Button(action: {
                    lessonVM.toggleBookmark(authVM: authVM)
                }) {
                    Image(systemName: lessonVM.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(lessonVM.isCurrentPageBookmarked ? .teal : .secondary)
                        .frame(width: 40, height: 40)
                        .background(lessonVM.isCurrentPageBookmarked ? Color.teal.opacity(0.15) : Color.secondary.opacity(0.15))
                        .clipShape(Circle())
                        .shadow(color: lessonVM.isCurrentPageBookmarked ? Color.teal.opacity(0.3) : .clear, radius: 6, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }

    private var lessonNavigationControls: some View {
        VStack(spacing: 16) {
            if lessonVM.currentPageIndex >= lessonVM.lessonPages.count - 1 && hasQuiz {
                NavigationLink(destination: UniversalTestView(mode: .quick(subject: subjectName, subtopic: lessonVM.currentLessonName))) {
                    HStack {
                        Text("Assess Knowledge")
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .font(.headline)
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.teal)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.teal.opacity(0.4), radius: 12, y: 4)
                }
                .padding(.horizontal, 24)
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        lessonVM.currentPageIndex = max(lessonVM.currentPageIndex - 1, 0)
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(lessonVM.currentPageIndex == 0 ? .gray.opacity(0.3) : .teal)
                        .frame(width: 50, height: 50)
                }
                .disabled(lessonVM.currentPageIndex == 0)

                Spacer()
                
                Text("\(lessonVM.currentPageIndex + 1) of \(lessonVM.lessonPages.count)")
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        lessonVM.currentPageIndex = min(lessonVM.currentPageIndex + 1, lessonVM.lessonPages.count - 1)
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(lessonVM.currentPageIndex == lessonVM.lessonPages.count - 1 ? .gray.opacity(0.3) : .teal)
                        .frame(width: 50, height: 50)
                }
                .disabled(lessonVM.currentPageIndex == lessonVM.lessonPages.count - 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    #endif
}
