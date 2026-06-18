import Combine
import SwiftUI
import UIKit
import WebKit

@MainActor
final class BrowserController: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published var title = "Browser"
    @Published var currentURL: URL?
    @Published var progress = 0.0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    let webView: WKWebView
    private var observations: [NSKeyValueObservation] = []

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in self?.progress = webView.estimatedProgress }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in self?.canGoBack = webView.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in self?.canGoForward = webView.canGoForward }
            }
        ]
    }

    func load(_ url: URL) {
        errorMessage = nil
        webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30))
    }

    func goBack() { if webView.canGoBack { webView.goBack() } }
    func goForward() { if webView.canGoForward { webView.goForward() } }
    func reload() { webView.reload() }
    func stop() { webView.stopLoading() }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
        isLoading = true
        currentURL = webView.url
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        isLoading = false
        title = webView.title ?? webView.url?.host() ?? "Browser"
        currentURL = webView.url
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
        isLoading = false
        errorMessage = error.localizedDescription
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
        isLoading = false
        errorMessage = error.localizedDescription
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let scheme = navigationAction.request.url?.scheme?.lowercased() else {
            decisionHandler(.cancel)
            return
        }
        if ["http", "https", "file", "about"].contains(scheme) {
            decisionHandler(.allow)
        } else {
            if let url = navigationAction.request.url { UIApplication.shared.open(url) }
            decisionHandler(.cancel)
        }
    }
}

struct BrowserWebView: UIViewRepresentable {
    @ObservedObject var controller: BrowserController

    func makeUIView(context: Context) -> WKWebView { controller.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

@MainActor
struct BrowserView: View {
    @StateObject private var controller: BrowserController
    @State private var address = ""
    @FocusState private var addressFocused: Bool

    init(url: URL) {
        let controller = BrowserController()
        _controller = StateObject(wrappedValue: controller)
        controller.load(url)
    }

    var body: some View {
        BrowserWebView(controller: controller)
            .safeAreaInset(edge: .top, spacing: 0) { addressBar }
            .safeAreaInset(edge: .bottom, spacing: 0) { browserToolbar }
            .navigationTitle(controller.title)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: controller.currentURL) { _, url in address = url?.absoluteString ?? "" }
            .alert("Unable to open page", isPresented: Binding(get: { controller.errorMessage != nil }, set: { if !$0 { controller.errorMessage = nil } })) {
                Button("Retry") { controller.reload() }
                Button("Cancel", role: .cancel) {}
            } message: { Text(controller.errorMessage ?? "Unknown error") }
    }

    private var addressBar: some View {
        VStack(spacing: 0) {
            if controller.progress < 1 { ProgressView(value: controller.progress).progressViewStyle(.linear) }
            HStack(spacing: 8) {
                Image(systemName: controller.currentURL?.scheme == "https" ? "lock.fill" : "globe")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Search or enter website", text: $address)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .keyboardType(.URL).submitLabel(.go).focused($addressFocused)
                    .onSubmit { navigate() }
                if addressFocused { Button("Cancel") { addressFocused = false; address = controller.currentURL?.absoluteString ?? "" } }
            }
            .padding(.horizontal, 12).frame(minHeight: 42)
            .background(TidePalette.subtle, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal).padding(.vertical, 8)
            .background(.bar)
        }
    }

    private var browserToolbar: some View {
        HStack {
            Button { controller.goBack() } label: { Image(systemName: "chevron.backward") }.disabled(!controller.canGoBack)
            Spacer()
            Button { controller.goForward() } label: { Image(systemName: "chevron.forward") }.disabled(!controller.canGoForward)
            Spacer()
            Button { controller.isLoading ? controller.stop() : controller.reload() } label: { Image(systemName: controller.isLoading ? "xmark" : "arrow.clockwise") }
            Spacer()
            if let url = controller.currentURL { ShareLink(item: url) { Image(systemName: "square.and.arrow.up") } }
            Spacer()
            if let url = controller.currentURL { Link(destination: url) { Image(systemName: "safari") } }
        }
        .font(.title3)
        .padding(.horizontal, 24).frame(height: 50)
        .background(.bar)
    }

    private func navigate() {
        addressFocused = false
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil {
            controller.load(url)
        } else if trimmed.contains("."), let url = URL(string: "https://\(trimmed)") {
            controller.load(url)
        } else if let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://duckduckgo.com/?q=\(encoded)") {
            controller.load(url)
        }
    }
}

struct BotPlatformView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var presentedSheet: BotPlatformSheet?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("bot_platform_title").font(.headline)
                    Text("bot_platform_summary").font(.footnote).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        commandChip("/newbot")
                        commandChip("/mybots")
                        commandChip("/setname")
                    }
                }
                .padding(.vertical, 4)
                if let docsURL {
                    NavigationLink { BrowserView(url: docsURL) } label: {
                        Label("Bot API Documentation", systemImage: "book.closed.fill")
                    }
                }
                Label("Tokens are stored in Keychain", systemImage: "key.fill")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Your bots") {
                if bots.isEmpty {
                    ContentUnavailableView("No bots", systemImage: "cpu", description: Text("Create a bot and connect it to your webhook server."))
                }
                ForEach(bots) { bot in
                    NavigationLink {
                        BotDetailView(bot: bot)
                    } label: {
                        HStack {
                            Image(systemName: "cpu.fill").frame(width: 38, height: 38).background(TidePalette.subtle, in: Circle())
                            VStack(alignment: .leading) {
                                Text(bot.name).fontWeight(.semibold)
                                Text("@\(bot.username)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Circle().fill(bot.isEnabled ? Color.primary : Color.secondary).frame(width: 8, height: 8)
                        }
                    }
                }
            }
        }
        .navigationTitle("Bot Platform")
        .toolbar { Button { presentedSheet = .create } label: { Image(systemName: "plus") } }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .create: CreateBotView()
            }
        }
    }

    private func commandChip(_ value: String) -> some View {
        Text(value)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(TidePalette.subtle, in: Capsule())
    }

    private var bots: [BotRecord] {
        guard let ownerID = dependencies.session.currentUser?.id else { return [] }
        return dependencies.database.bots(ownerID: ownerID)
    }

    private var docsURL: URL? {
        Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Docs")
            ?? Bundle.main.url(forResource: "index", withExtension: "html")
    }
}

enum BotPlatformSheet: String, Identifiable {
    case create
    var id: String { rawValue }
}

struct CreateBotView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var username = ""
    @State private var token = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Display name", text: $name)
                    TextField("Username", text: $username).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("Token") {
                    SecureField("Bot token", text: $token)
                    Text("Create the token on your Tide Bot API server. The iOS app stores it only in Keychain.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Create Bot")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Create", action: create).disabled(!isValid) }
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && username.count >= 5
            && username.lowercased().hasSuffix("bot")
            && token.count >= 20
    }

    private func create() {
        guard let ownerID = dependencies.session.currentUser?.id else { return }
        do {
            try dependencies.database.createBot(ownerID: ownerID, name: name, username: username, token: token)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct BotDetailView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    let bot: BotRecord
    @State private var webhook = ""
    @State private var enabled = true
    @State private var saved = false

    var body: some View {
        Form {
            Section("Bot") {
                LabeledContent("Name", value: bot.name)
                LabeledContent("Username", value: "@\(bot.username)")
                Toggle("Enabled", isOn: $enabled)
            }
            Section("Webhook") {
                TextField("https://example.com/tide/webhook", text: $webhook)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("Use HTTPS and verify the X-Tide-Bot-Secret header on every update.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Button("Save") {
                    dependencies.database.updateBot(bot, webhookURL: URL(string: webhook), enabled: enabled)
                    saved = true
                }
                Button("Delete Bot", role: .destructive) {
                    dependencies.database.deleteBot(bot)
                    dismiss()
                }
            }
            if saved { Label("Saved", systemImage: "checkmark.circle.fill") }
        }
        .navigationTitle(bot.name)
        .onAppear {
            webhook = bot.webhookURLString ?? ""
            enabled = bot.isEnabled
        }
    }
}

struct ShareView: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL

    var body: some View {
        NavigationStack {
            List {
                ShareLink(item: url) { Label("Share with another app", systemImage: "square.and.arrow.up") }
                Button { UIPasteboard.general.url = url; dismiss() } label: { Label("Copy Link", systemImage: "link") }
                Link(destination: url) { Label("Open in Safari", systemImage: "safari") }
            }
            .navigationTitle("Share")
            .toolbar { Button("Done") { dismiss() } }
        }
        .presentationDetents([.medium])
    }
}
