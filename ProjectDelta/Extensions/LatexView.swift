//
//  LatexView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/21/24.
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
    @State private var isLoading = true
    @State private var dynamicHeight: CGFloat = 60
    
    var body: some View {
        ZStack {
            LatexWebView(latex: latex, dynamicHeight: $dynamicHeight, isLoading: $isLoading)
                .frame(height: max(dynamicHeight, 60))
                #if os(macOS)
                .allowsHitTesting(false) // Prevents the WKWebView from intercepting scroll wheel events on Mac
                #endif
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.primary)
            }
        }
    }
}

struct LatexWebView: PlatformViewRepresentable {
    var latex: String
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
        
        // Inject script to observe height changes and send them to Swift
        let js = """
        const resizeObserver = new ResizeObserver(entries => {
            for (let entry of entries) {
                window.webkit.messageHandlers.heightHandler.postMessage(entry.target.offsetHeight);
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
        let latexTextColor = colorScheme == .dark ? "cyan" : "red"

        // Old Regex for *blue* highlighting
        let processedLatex = latex
            .replacingOccurrences(of: "\\*blue (.*?) blue\\*", with: "\\\\textcolor{\(latexTextColor)}{$1}", options: .regularExpression)
            .replacingOccurrences(of: "\\n", with: "\\\\\\")
        
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            <style>
                body {
                    font-size: 110%;
                    color: \(textColor);
                    background-color: transparent;
                    margin: 0;
                    padding: 8px 0px; /* Padding to prevent vertical clipping */
                    display: flex;
                    align-items: center;
                    justify-content: flex-start;
                    overflow: hidden; /* Added to stop internal element scrolling */
                }
                #math-container {
                    display: inline-block;
                    width: 100%;
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
                                window.webkit.messageHandlers.heightHandler.postMessage(container.offsetHeight);
                            });
                        }
                    }
                };
            </script>
        </head>
        <body>
            <div id="math-container">
                \(processedLatex)
            </div>
        </body>
        </html>
        """
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: LatexWebView
        
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
                    // Add buffer to ensure bottom of fractions aren't trimmed
                    let calculatedHeight = height + 15
                    if calculatedHeight > self.parent.dynamicHeight {
                        self.parent.dynamicHeight = calculatedHeight
                    }
                }
            }
        }
    }
}
