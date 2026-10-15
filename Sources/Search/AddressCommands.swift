import Foundation

// The address field doubles as the most basic kind of command line: a
// handful of words that mean "go here in the app" rather than "go here on
// the web". Only ever the whole of what was typed, so a search that merely
// starts with one of these words still searches. Off by default (Settings ›
// General › Address bar commands): nobody typing "settings" into a browser
// expects the app to open its own panel instead of asking Google.
//
// Not the menus' Command (Shortcuts.swift): these are words, not keys.

@MainActor
enum AddressCommand: CaseIterable, Equatable {
    case settings
    case newTab
    case newPrivateTab
    case newSpace
    case bookmarks
    case history
    case downloads
    case passwords
    case toggleSidebar

    /// What you'd type to reach it. The first is what the list shows: the
    /// word in the app's language, then the English ones, which always work.
    var aliases: [String] {
        let english: [String]
        let own: String
        switch self {
        case .settings: english = ["settings", "preferences"]; own = String(localized: "settings", comment: "Typed alone in the address field to open Settings, in lowercase")
        case .newTab: english = ["new tab"]; own = String(localized: "new tab", comment: "Typed alone in the address field, in lowercase")
        case .newPrivateTab: english = ["new private tab", "private tab"]; own = String(localized: "new private tab", comment: "Typed alone in the address field, in lowercase")
        case .newSpace: english = ["new space"]; own = String(localized: "new space", comment: "Typed alone in the address field, in lowercase")
        case .bookmarks: english = ["bookmarks"]; own = String(localized: "bookmarks", comment: "Typed alone in the address field, in lowercase")
        case .history: english = ["history"]; own = String(localized: "history", comment: "Typed alone in the address field, in lowercase")
        case .downloads: english = ["downloads"]; own = String(localized: "downloads", comment: "Typed alone in the address field, in lowercase")
        case .passwords: english = ["passwords"]; own = String(localized: "passwords", comment: "Typed alone in the address field, in lowercase")
        case .toggleSidebar: english = ["toggle sidebar", "sidebar"]; own = String(localized: "toggle sidebar", comment: "Typed alone in the address field, in lowercase")
        }
        return english.contains(own) ? english : [own] + english
    }

    /// Title Case in English, as menus have it; only the first letter
    /// elsewhere, as French menus have it.
    var title: String {
        let words = aliases[0]
        if Bundle.main.preferredLocalizations.first == "en" { return words.localizedCapitalized }
        return words.prefix(1).localizedUppercase + words.dropFirst()
    }

    /// Some only mean something once the feature behind them is even on.
    func available(in browser: Browser) -> Bool {
        switch self {
        case .newSpace: return browser.prefs.usesSpaces
        default: return true
        }
    }

    func run(on browser: Browser) {
        switch self {
        case .settings: browser.tuning = true
        case .newTab: browser.newTab()
        case .newPrivateTab: browser.newShyTab()
        case .newSpace: browser.makingSpace = true
        case .bookmarks: browser.bookmarking = true
        case .history: browser.recalling = true
        case .downloads: browser.hoarding = true
        case .passwords: browser.managing = true
        case .toggleSidebar: browser.toggleSidebar()
        }
    }

    /// The command whose words are all that was typed, if any. Only the
    /// whole thing, never a prefix or a near miss: a command must not take a
    /// search from anyone, so "settings for gmail" or "sett" still searches.
    static func matching(_ typed: String, in browser: Browser) -> AddressCommand? {
        let needle = typed.trimmingCharacters(in: .whitespaces).lowercased()
        return allCases.first { $0.available(in: browser) && $0.aliases.contains(needle) }
    }
}
