import Foundation

// A number and the thing it counts, said in the app's language: "1 bookmark",
// "1,204 bookmarks", "1 204 signets". One is singular in English and in
// French alike, so a choice between two whole phrases is enough, and the
// number keeps the Mac's own grouping (a plural rule in a .stringsdict would
// print it bare). Each phrase is whole, for the translation to reword.

enum Noun {
    case bookmark, newBookmark, place, password, account, space, newSpace, pin, pinnedTab, profile, page
}

func counted(_ n: Int, _ noun: Noun) -> String {
    let number = n.formatted()
    let one = n == 1
    switch noun {
    case .bookmark: return one ? String(localized: "1 bookmark") : String(localized: "\(number) bookmarks")
    case .newBookmark: return one ? String(localized: "1 new bookmark") : String(localized: "\(number) new bookmarks")
    case .place: return one ? String(localized: "1 place") : String(localized: "\(number) places")
    case .password: return one ? String(localized: "1 password") : String(localized: "\(number) passwords")
    case .account: return one ? String(localized: "1 account") : String(localized: "\(number) accounts")
    case .space: return one ? String(localized: "1 space") : String(localized: "\(number) spaces")
    case .newSpace: return one ? String(localized: "1 new space") : String(localized: "\(number) new spaces")
    case .pin: return one ? String(localized: "1 pin") : String(localized: "\(number) pins")
    case .pinnedTab: return one ? String(localized: "1 pinned tab") : String(localized: "\(number) pinned tabs")
    case .profile: return one ? String(localized: "1 profile") : String(localized: "\(number) profiles")
    case .page: return one ? String(localized: "1 page") : String(localized: "\(number) pages")
    }
}
