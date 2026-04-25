import AppKit
import Foundation

/// Fallbacks for fetching now-playing artwork when MediaRemote doesn't supply it.
/// Tries Spotify (artwork URL → download) then Music.app (raw bytes via /tmp).
enum MediaArtworkFetcher {
    static func fetch(matchingTitle expectedTitle: String,
                      completion: @escaping (Data?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let data = fetchSpotify(matching: expectedTitle) {
                completion(data); return
            }
            if let data = fetchMusic(matching: expectedTitle) {
                completion(data); return
            }
            completion(nil)
        }
    }

    // MARK: - Spotify

    private static func fetchSpotify(matching title: String) -> Data? {
        let script = """
        try
            tell application id "com.spotify.client"
                if it is not running then return ""
                set s to player state as text
                if s is "stopped" then return ""
                return (artwork url of current track as text) & "|" & (name of current track as text)
            end tell
        on error
            return ""
        end try
        """
        guard let result = runAppleScript(script), !result.isEmpty else { return nil }
        let parts = result.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let urlString = String(parts[0])
        let trackName = String(parts[1])
        // Loose match — strip whitespace, case-insensitive substring either way
        guard matches(trackName, title) else { return nil }
        guard let url = URL(string: urlString) else { return nil }
        return try? Data(contentsOf: url, options: [.uncached])
    }

    // MARK: - Music.app

    private static func fetchMusic(matching title: String) -> Data? {
        let tmpPath = NSTemporaryDirectory().appending("notchani-artwork.tiff")
        // Music.app exposes raw artwork bytes. Write them to a tmp file and read back.
        let script = """
        try
            tell application "Music"
                if it is not running then return ""
                set ps to player state as text
                if ps is "stopped" then return ""
                set ct to current track
                set tName to (name of ct as text)
                if (count of artworks of ct) is 0 then return ""
                set artData to data of artwork 1 of ct
                set tmp to POSIX file "\(tmpPath)"
                try
                    set fd to open for access tmp with write permission
                    set eof fd to 0
                    write artData to fd
                    close access fd
                on error
                    try
                        close access tmp
                    end try
                    return ""
                end try
                return tName
            end tell
        on error
            return ""
        end try
        """
        guard let trackName = runAppleScript(script), !trackName.isEmpty else { return nil }
        guard matches(trackName, title) else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: tmpPath))
    }

    // MARK: - Helpers

    private static func runAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var err: NSDictionary?
        let result = script.executeAndReturnError(&err)
        if err != nil { return nil }
        return result.stringValue
    }

    private static func matches(_ a: String, _ b: String) -> Bool {
        let na = normalize(a)
        let nb = normalize(b)
        guard !na.isEmpty, !nb.isEmpty else { return false }
        return na.contains(nb) || nb.contains(na)
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
