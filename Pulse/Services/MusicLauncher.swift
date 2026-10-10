import SwiftUI

/// Opens the user's music app. Universal links open the installed app, or the website if it isn't installed.
/// Only Spotify offers a playback-control SDK; YouTube Music has no public API, so for it we just open the app or a playlist link.
enum MusicApp: String, CaseIterable, Identifiable {
    case spotify, youtubeMusic, appleMusic
    var id: String { rawValue }

    var label: String {
        switch self {
        case .spotify: "Spotify"
        case .youtubeMusic: "YouTube Music"
        case .appleMusic: "Apple Music"
        }
    }

    var url: URL {
        switch self {
        case .spotify: URL(string: "https://open.spotify.com")!
        case .youtubeMusic: URL(string: "https://music.youtube.com")!
        case .appleMusic: URL(string: "https://music.apple.com")!
        }
    }
}

/// Menu button for the workout screen: opens a music app or the playlist saved in Settings.
struct MusicMenu: View {
    @AppStorage("playlistURL") private var playlistURL = ""
    @Environment(\.openURL) private var openURL

    var body: some View {
        Menu {
            if let url = URL(string: playlistURL.trimmingCharacters(in: .whitespaces)), url.scheme?.hasPrefix("http") == true {
                Button("La tua playlist", systemImage: "music.note.list") { openURL(url) }
            }
            ForEach(MusicApp.allCases) { app in
                Button(app.label, systemImage: "music.note") { openURL(app.url) }
            }
        } label: {
            Image(systemName: "music.note")
        }
        .accessibilityLabel("Musica")
    }
}
