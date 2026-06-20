import SwiftUI
import WebKit

struct SVGRemoteView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        load(url, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastURL != url else { return }
        context.coordinator.lastURL = url
        load(url, in: webView)
    }

    private func load(_ url: URL, in webView: WKWebView) {
        if url.isFileURL {
            if let data = try? Data(contentsOf: url) {
                if let svg = String(data: data, encoding: .utf8) {
                    let html = """
                    <!DOCTYPE html>
                    <html>
                    <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
                    <style>
                    html, body {
                        margin: 0;
                        width: 100%;
                        height: 100%;
                        overflow: hidden;
                        background: transparent;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                    }
                    svg {
                        width: 100%;
                        height: 100%;
                        display: block;
                    }
                    </style>
                    </head>
                    <body>\(svg)</body>
                    </html>
                    """
                    webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
                } else {
                    webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
                }
            } else {
                webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            }
        } else {
            webView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastURL: URL?
    }
}
