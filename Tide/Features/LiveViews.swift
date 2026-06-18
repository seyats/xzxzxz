import SwiftUI

struct LiveHubView: View {
    @State private var streams: [LiveStream] = []
    @State private var query = ""
    @State private var presentedSheet: LiveSheet?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(filteredStreams) { stream in
                    NavigationLink { LiveViewer(stream: stream) } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18).fill(TidePalette.subtle).aspectRatio(0.9, contentMode: .fit)
                                Image(systemName: stream.symbol).font(.system(size: 50))
                                VStack {
                                    HStack {
                                        Text(stream.isLive ? "LIVE" : "SOON")
                                            .font(.caption.bold()).padding(6)
                                            .background(stream.isLive ? TidePalette.ink : Color.secondary, in: Capsule())
                                            .foregroundStyle(TidePalette.inverse)
                                        Spacer()
                                    }
                                    Spacer()
                                }
                                .padding(8)
                            }
                            Text(stream.title).font(.headline).lineLimit(2)
                            Text("\(stream.host.name) · \(stream.viewerCount.formatted(.number.notation(.compactName))) watching")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .searchable(text: $query, prompt: "Streams and creators")
        .navigationTitle("Tide Live")
        .toolbar { Button("Go Live") { presentedSheet = .create } }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .create:
                CreateLiveView { stream in streams.insert(stream, at: 0) }
            }
        }
    }

    private var filteredStreams: [LiveStream] {
        query.isEmpty ? streams : streams.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.host.name.localizedCaseInsensitiveContains(query) }
    }
}

struct LiveViewer: View {
    let stream: LiveStream
    @State private var message = ""
    @State private var messages: [String] = []
    @State private var isFollowing = false
    @State private var heartCount = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(systemName: stream.symbol).font(.system(size: 120, weight: .thin)).foregroundStyle(.white.opacity(0.7))
            VStack {
                HStack {
                    Text("LIVE").font(.caption.bold()).padding(7).background(.white, in: Capsule()).foregroundStyle(.black)
                    Text(stream.title).fontWeight(.semibold)
                    Spacer()
                    Text(stream.viewerCount.formatted())
                    Button(isFollowing ? "Following" : "Follow") { isFollowing.toggle() }.buttonStyle(.bordered)
                }
                .foregroundStyle(.white)
                Spacer()
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(messages.suffix(5), id: \.self) { Text($0).foregroundStyle(.white) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    TextField("Say something", text: $message)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(.white.opacity(0.15), in: Capsule()).foregroundStyle(.white)
                    Button { send() } label: { Image(systemName: "paperplane.fill").foregroundStyle(.white) }.disabled(message.isEmpty)
                    Button { heartCount += 1 } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                            if heartCount > 0 { Text(heartCount.formatted()).font(.caption) }
                        }
                        .foregroundStyle(.white).font(.title2)
                    }
                }
            }
            .padding()
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func send() {
        messages.append("you: \(message)")
        message = ""
    }
}

enum LiveSheet: String, Identifiable {
    case create
    var id: String { rawValue }
}

struct CreateLiveView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category = "Creative"
    @State private var isPrivate = false
    let created: (LiveStream) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Broadcast") {
                    TextField("Title", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(["Creative", "Music", "Technology", "News", "Gaming"], id: \.self) { Text($0).tag($0) }
                    }
                    Toggle("Private stream", isOn: $isPrivate)
                }
                Section {
                    Label("Camera and microphone permissions will be requested when the broadcast begins.", systemImage: "video.fill")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Go Live")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Start", action: start).disabled(title.isEmpty) }
            }
        }
    }

    private func start() {
        guard let host = dependencies.session.currentUser else { return }
        created(LiveStream(id: UUID(), host: host, title: title, category: category, viewerCount: isPrivate ? 1 : 0, isLive: true, symbol: host.avatarSymbol))
        dismiss()
    }
}

