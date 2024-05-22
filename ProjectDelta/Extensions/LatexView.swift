//
//  LatexView.swift
//  ProjectDelta
//
//  Created by Jake Meissner on 5/21/24.
//

import SwiftUI
import WebKit

struct LatexView: UIViewRepresentable {
    let latex: String
    @Environment(\.colorScheme) var colorScheme

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let backgroundColor = colorScheme == .dark ? "black" : "white"
        let textColor = colorScheme == .dark ? "white" : "black"
        
        let htmlString = """
        <!DOCTYPE html>
        <html>
        <head>
            <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            <style>
                body {
                    font-size: 3.0em;
                    color: \(textColor);
                    background-color: \(backgroundColor);
                    margin: 0;
                    padding: 0;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    height: 100%;
                }
                #math-content {
                    display: inline-block;
                }
            </style>
        </head>
        <body>
            <div id="math-content">
                \(latex)
            </div>
            <script>
                MathJax.typeset();
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(htmlString, baseURL: nil)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: ()) {
        uiView.stopLoading()
    }
}





