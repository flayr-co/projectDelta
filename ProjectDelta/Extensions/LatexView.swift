//
//  LatexView.swift
//  ProjectDelta
//

import SwiftUI
import WebKit

#if os(iOS)
import UIKit
typealias PlatformViewRepresentable = UIViewRepresentable
#elseif os(macOS)
import AppKit
typealias PlatformViewRepresentable = NSViewRepresentable
#endif

struct LatexView: View {
    var latex: String
    var isTextMode: Bool = false
    @State private var isLoading = true
    @State private var dynamicHeight: CGFloat = 40
    @State private var currentScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            LatexWebView(latex: latex, isTextMode: isTextMode, dynamicHeight: $dynamicHeight, isLoading: $isLoading)
                .frame(height: max(dynamicHeight, isTextMode ? 24 : 40))
                .allowsHitTesting(false)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(isTextMode ? 0.8 : 1.2)
                    .tint(.primary)
            }
        }
        .contentShape(Rectangle())
        .scaleEffect(currentScale)
        .gesture(
            MagnificationGesture()
                .onChanged { val in
                    currentScale = max(1.0, min(val, 4.0))
                }
                .onEnded { _ in
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                        currentScale = 1.0
                    }
                }
        )
        .zIndex(currentScale > 1.0 ? 999 : 0)
        .shadow(color: currentScale > 1.0 ? Color.black.opacity(0.15) : .clear, radius: 20, y: 10)
    }
}

struct LatexWebView: PlatformViewRepresentable {
    var latex: String
    var isTextMode: Bool
    @Binding var dynamicHeight: CGFloat
    @Binding var isLoading: Bool
    @Environment(\.colorScheme) var colorScheme
    
    #if os(iOS)
    func makeUIView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        updateWebView(webView, context: context)
    }
    #elseif os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        updateWebView(webView, context: context)
    }
    #endif
    
    private func makeWebView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        
        let js = """
        const resizeObserver = new ResizeObserver(entries => {
            for (let entry of entries) {
                window.webkit.messageHandlers.heightHandler.postMessage(entry.target.scrollHeight);
            }
        });
        resizeObserver.observe(document.getElementById('math-container'));
        """
        
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(userScript)
        userContentController.add(context.coordinator, name: "heightHandler")
        configuration.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        #if os(iOS)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        #elseif os(macOS)
        webView.setValue(false, forKey: "drawsBackground")
        #endif
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    private func updateWebView(_ webView: WKWebView, context: Context) {
        let textColor = colorScheme == .dark ? "white" : "black"
        let cyanColor = colorScheme == .dark ? "cyan" : "blue"
        let redColor = colorScheme == .dark ? "#FF6B6B" : "red"
        let greenColor = colorScheme == .dark ? "#4ADE80" : "green"
        
        var processedLatex = latex
            .replacingOccurrences(of: "\\*blue (.*?) blue\\*", with: "\\\\textcolor{\(cyanColor)}{$1}", options: .regularExpression)
            .replacingOccurrences(of: "blue(.*?)blue", with: "\\\\textcolor{\(cyanColor)}{$1}", options: .regularExpression)
            .replacingOccurrences(of: "\\*red (.*?) red\\*", with: "\\\\textcolor{\(redColor)}{$1}", options: .regularExpression)
            .replacingOccurrences(of: "red(.*?)red", with: "\\\\textcolor{\(redColor)}{$1}", options: .regularExpression)
            .replacingOccurrences(of: "\\*green (.*?) green\\*", with: "\\\\textcolor{\(greenColor)}{$1}", options: .regularExpression)
            .replacingOccurrences(of: "green(.*?)green", with: "\\\\textcolor{\(greenColor)}{$1}", options: .regularExpression)
            .replacingOccurrences(of: "\\\\bm", with: "\\\\boldsymbol ")
            .replacingOccurrences(of: "\n", with: isTextMode ? "<br>" : " \\\\ ")
            .replacingOccurrences(of: "\\n", with: isTextMode ? "<br>" : " \\\\ ")
        
        if isTextMode {
            processedLatex = processedLatex.replacingOccurrences(of: "\\*\\*(.*?)\\*\\*", with: "<b>$1</b>", options: .regularExpression)
        }
        
        let displayStyle = isTextMode ? "display: block;" : "display: flex; align-items: center; justify-content: flex-start;"
        let paddingStyle = isTextMode ? "padding: 2px 0px;" : "padding: 12px 4px;"
        let fontSize = isTextMode ? "18px" : "110%"
        let fontWeight = isTextMode ? "500" : "normal"
        let opacity = isTextMode ? "0.85" : "1.0"
        
        let htmlString = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Rounded", "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                        font-size: \(fontSize);
                        font-weight: \(fontWeight);
                        line-height: 1.6;
                        color: \(textColor);
                        opacity: \(opacity);
                        background-color: transparent;
                        margin: 0;
                        -webkit-tap-highlight-color: transparent;
                        \(paddingStyle)
                        \(displayStyle)
                        overflow: visible;
                    }
                    #math-container {
                        display: inline-block;
                        width: 100%;
                        word-wrap: break-word;
                    }
                </style>
                <script>
                    window.MathJax = {
                        tex: {
                            inlineMath: [['$', '$'], ['\\\\(', '\\\\)']],
                            displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']],
                            processEscapes: true,
                            tags: 'none'
                        },
                        options: {
                            skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre'],
                            ignoreHtmlClass: 'tex2jax_ignore',
                            processHtmlClass: 'tex2jax_process'
                        },
                        svg: {
                            fontCache: 'global'
                        },
                        startup: {
                            pageReady: () => {
                                return MathJax.startup.defaultPageReady().then(() => {
                                    let container = document.getElementById('math-container');
                                    window.webkit.messageHandlers.heightHandler.postMessage(container.scrollHeight);
                                });
                            }
                        }
                    };
                </script>
                <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            </head>
            <body>
                <div id="math-container">
                    \(processedLatex)
                </div>
            </body>
            </html>
            """
        
        if context.coordinator.lastLoadedHTML != htmlString {
            context.coordinator.lastLoadedHTML = htmlString
            webView.loadHTMLString(htmlString, baseURL: nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: LatexWebView
        var lastLoadedHTML: String? = nil
        
        init(_ parent: LatexWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightHandler", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    let calculatedHeight = height + (self.parent.isTextMode ? 5 : 15)
                    if calculatedHeight > self.parent.dynamicHeight {
                        self.parent.dynamicHeight = calculatedHeight
                    }
                }
            }
        }
    }
}


