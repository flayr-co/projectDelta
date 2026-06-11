//
//  LatexView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/21/24.
//

//
//  LatexView.swift
//  ProjectDelta
//

import SwiftUI
import WebKit

struct LatexView: View {
    var latex: String
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            LatexWebView(latex: latex, isLoading: $isLoading)
            
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Prevents layout shifting during the load process
                .background(Color.clear)
            }
        }
    }
}

// Wrapping pure WebView inside Representable is fundamentally required to compute MathJax
struct LatexWebView: UIViewRepresentable {
    var latex: String
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
        <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
        <style>
            body { 
                margin: 0; 
                display: flex; 
                justify-content: flex-start; 
                align-items: center; 
                font-size: 110%; 
                color: var(--text-color, #000); 
                background: transparent;
                padding-left: 8px;
            }
        </style>
        </head>
        <body>
            <div>\(latex)</div>
        </body>
        </html>
        """
        uiView.loadHTMLString(htmlString, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: LatexWebView
        
        init(_ parent: LatexWebView) {
            self.parent = parent
        }
        
        // Triggers the loading indicator shutdown as soon as the MathJax DOM tree registers
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}
