import Foundation

// Which language Search speaks. macOS decides, as for any app: the first of
// the languages in System Settings › General › Language & Region that Search
// has words for (English, French), or the one chosen for Search alone under
// Applications there. Nothing to set in Search itself. The French is in
// Localization/fr.lproj, which build.sh puts in the app.
//
// A test run is the exception: it speaks English whatever the Mac does, so
// the bench and the tests, which find menus and read messages by their
// words, read the same words on every Mac. SEARCH_LANGUAGE=fr beside
// SEARCH_PROBE asks for another.
enum Language {
    /// First thing at launch: AppKit settles on a language the first time a
    /// word is looked up, and keeps it.
    static func settle() {
        guard Store.testing else { return }
        let asked = ProcessInfo.processInfo.environment["SEARCH_LANGUAGE"] ?? "en"
        // The arguments' domain is read before anything else; what the
        // command line put there stays.
        var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        arguments["AppleLanguages"] = [asked]
        UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
    }
}
