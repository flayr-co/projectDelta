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
    @State private var lastContentOffset: CGFloat = 0
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
        #endif
        .task {
            lessonVM.subjectName = subjectName
            await lessonVM.initializeLesson(subjectName: subjectName, authVM: authVM)
        }
        .task(id: lessonVM.currentLessonName) {
            guard !lessonVM.currentLessonName.isEmpty else { return }
            let db = Firestore.firestore()
            do {
                // 1. Direct ID check
                let byIdSnap = try? await db.collection("Subjects").document(subjectName).collection("Tests")
                    .whereField("subtopic", isEqualTo: lessonVM.currentLessonName).limit(to: 1).getDocuments()
                
                if let docs = byIdSnap?.documents, !docs.isEmpty {
                    withAnimation { hasQuiz = true }
                    return
                }
                
                // 2. Name field check (Bypasses empty ghost documents)
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
    }

    // MARK: - DESKTOP LAYOUT (macOS)
        #if os(macOS)
        private var macOSLayout: some View {
            ZStack {
                (colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.95, green: 0.95, blue: 0.97)).ignoresSafeArea()

                VStack(spacing: 0) {
                    if showUIControls {
                        macOSHeaderView
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if lessonVM.isLoading {
                        Spacer()
                        ProgressView("Loading lesson content...")
                            .tint(.cyan)
                        Spacer()
                    } else if lessonVM.lessonPages.isEmpty {
                        Spacer()
                        Text("No content available.")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Spacer()
                    } else {
                        // Custom macOS Paging (Avoids TabView tab-style rendering)
                        ZStack {
                            if lessonVM.lessonPages.indices.contains(lessonVM.currentPageIndex) {
                                let page = lessonVM.lessonPages[lessonVM.currentPageIndex]
                                ScrollView(.vertical, showsIndicators: false) {
                                    LessonContentPage(
                                        page: page,
                                        isInteractingWithExplanation: $isInteractingWithExplanation,
                                        onBackgroundTap: {}
                                    )
                                    .padding(.vertical, 40)
                                    .frame(maxWidth: 1000, alignment: .leading)
                                }
                                .id(page.id)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                    removal: .opacity.combined(with: .scale(scale: 1.02))
                                ))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onChange(of: lessonVM.currentPageIndex) { oldValue, newPageIndex in
                            if lessonVM.lessonPages.indices.contains(newPageIndex) {
                                let newPageNumber = lessonVM.lessonPages[newPageIndex].pageNumber
                                lessonVM.navigateToPage(lessonName: lessonVM.currentLessonName, pageNumber: newPageNumber, authVM: authVM)
                            }
                        }
                    }

                    if !lessonVM.isLoading && !lessonVM.lessonPages.isEmpty && showUIControls {
                        macOSNavigationControls
                            .transition(.move(edge: .bottom).combined(with: .opacity))
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

                    TableOfContentsView(lessonVM: lessonVM, subjectName: subjectName, isShowing: $showTableOfContents)
                        .frame(width: 360)
                        .background(colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : .white)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.2), radius: 30)
                        .transition(.move(edge: .trailing))
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }

        private var macOSHeaderView: some View {
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subjectName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    
                    Text(lessonVM.currentLessonName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.cyan)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showTableOfContents.toggle()
                            if showTableOfContents {
                                lessonVM.fetchAllLessons(for: subjectName)
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("Index")
                        }
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        .foregroundStyle(colorScheme == .dark ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    Button(action: {
                        lessonVM.toggleBookmark(authVM: authVM)
                    }) {
                        Image(systemName: lessonVM.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.headline)
                            .foregroundColor(lessonVM.isCurrentPageBookmarked ? .cyan : (colorScheme == .dark ? .white : .primary))
                            .padding(14)
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                            .padding(14)
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
            .background(colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : .white)
            .overlay(
                Rectangle().frame(height: 1).foregroundColor(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)),
                alignment: .bottom
            )
        }

    private var macOSNavigationControls: some View {
        HStack {
            Button(action: {
                withAnimation {
                    lessonVM.currentPageIndex = max(lessonVM.currentPageIndex - 1, 0)
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "chevron.left").font(.title3.bold())
                    Text("Previous").font(.title3).fontWeight(.bold)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .foregroundStyle(colorScheme == .dark ? .white : .primary)
                .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .disabled(lessonVM.currentPageIndex == 0)
            .opacity(lessonVM.currentPageIndex == 0 ? 0.3 : 1)
            
            Spacer()
            
            if lessonVM.currentPageIndex >= lessonVM.lessonPages.count - 1 && hasQuiz {
                NavigationLink(destination: UniversalTestView(mode: .quick(subject: subjectName, subtopic: lessonVM.currentLessonName))) {
                    Text("Take Practice Quiz")
                        .font(.title3)
                        .fontWeight(.bold)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [.green.opacity(0.85), .green.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Text("Page \(lessonVM.currentPageIndex + 1) of \(lessonVM.lessonPages.count)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    lessonVM.currentPageIndex = min(lessonVM.currentPageIndex + 1, lessonVM.lessonPages.count - 1)
                }
            }) {
                HStack(spacing: 12) {
                    Text("Next").font(.title3).fontWeight(.bold)
                    Image(systemName: "chevron.right").font(.title3.bold())
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(colors: [.cyan.opacity(0.85), .cyan.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .disabled(lessonVM.currentPageIndex == lessonVM.lessonPages.count - 1)
            .opacity(lessonVM.currentPageIndex == lessonVM.lessonPages.count - 1 ? 0.3 : 1)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
        .background(colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : .white)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)),
            alignment: .top
        )
    }
        #endif

    // MARK: - MOBILE LAYOUT (iOS)
    #if os(iOS)
    private var iOSLayout: some View {
        ZStack {
            (colorScheme == .dark ? Color.customDarkGray : Color.white)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if showUIControls {
                    headerView
                        .transition(.opacity)
                }

                if lessonVM.isLoading {
                    Spacer()
                    ProgressView("Loading lesson content...")
                    Spacer()
                } else if lessonVM.lessonPages.isEmpty {
                    Spacer()
                    Text("No content available.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
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
                    .background(colorScheme == .dark ? Color.customDarkGray : .white)
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
                        .foregroundStyle(colorScheme == .dark ? .mint : .blue)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: {
                    lessonVM.toggleBookmark(authVM: authVM)
                }) {
                    Image(systemName: lessonVM.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 18))
                        .foregroundColor(lessonVM.isCurrentPageBookmarked ? .blue : .secondary)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(colorScheme == .dark ? Color.customDarkGray : .white)
    }

    private var lessonNavigationControls: some View {
        VStack {
            if lessonVM.currentPageIndex >= lessonVM.lessonPages.count - 1 && hasQuiz {
                // MARK: Routing updated to UniversalTestView
                NavigationLink(destination: UniversalTestView(mode: .quick(subject: subjectName, subtopic: lessonVM.currentLessonName))) {
                    Text("Take Quiz")
                        .font(.headline)
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(colorScheme == .dark ? .cyan : .green)
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
                        .foregroundStyle(colorScheme == .dark ? .cyan : .blue)
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
                        .foregroundStyle(colorScheme == .dark ? .cyan : .blue)
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
    #endif
}

#Preview {
    let auth = AuthViewModel()
    LessonView(subjectName: "Algebra")
    .environment(LessonViewModel())
    .environment(auth)
    .environment(TestSessionViewModel(authViewModel: auth))
}
