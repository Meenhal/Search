import SwiftUI

// The band at the top of the page's card, with the tabs down the side, as in
// Dia: the column shown or folded away, back, forward and reload, where the
// page is, and at the far end the downloads, the extensions and the
// bookmarks; under them, the bookmarks bar when it is on, as Dia has it. A
// click anywhere on the address raises the field to change it.
//
// It is drawn under the page and reaches past the band by the card's corner,
// so the page's rounded top corners show the band's white, not the frame's
// grey: band and page read as one card.

struct AddressBand: View {
    @ObservedObject var browser: Browser
    /// The bookmarks bar under the doors.
    let bar: Bool

    static let height: CGFloat = 38

    /// The band's whole height, the bookmarks bar included.
    static func height(bar: Bool) -> CGFloat { height + (bar ? BookmarksBar.height : 0) }

    var body: some View {
        VStack(spacing: 0) {
            doors
            if bar {
                BookmarksBar(browser: browser, bookmarks: browser.bookmarks, inBand: true)
                    .transition(.opacity)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: Metrics.cardRadius, topTrailingRadius: Metrics.cardRadius,
                                   style: .continuous)
                .fill(Palette.ground)
                .shadow(color: .black.opacity(CardEdge.shadow), radius: 6, y: 1)
        }
        .overlay {
            UnevenRoundedRectangle(topLeadingRadius: Metrics.cardRadius, topTrailingRadius: Metrics.cardRadius,
                                   style: .continuous)
                .strokeBorder(Color.primary.opacity(CardEdge.edge), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private var doors: some View {
        // The column folded away takes the window's lights with it (see
        // Fold), so the doors start at the card's own edge either way.
        HStack(spacing: 4) {
            Door(icon: "sidebar.left", help: browser.folded ? "Show the tabs   ⌘S" : "Hide the tabs   ⌘S") {
                browser.toggleFold()
            }
            Helm(browser: browser)
            if let tab = browser.active, !tab.isBlank {
                Where(browser: browser, tab: tab)
            } else {
                // Nothing to show: the run drags the window, as a title bar
                // does. Only there: a strip under the doors would take their
                // clicks first.
                DragStrip()
                    .frame(maxWidth: .infinity)
            }
            FetchDoor(browser: browser, fetches: browser.fetches)
            ExtensionSlot(edge: .bottom)
            BookmarkDoor(browser: browser, arrowEdge: .bottom)
        }
        .padding(.horizontal, 8)
        .frame(height: AddressBand.height)
    }

    /// The site, then the page's title: what the tab is, at a glance.
    private struct Where: View {
        let browser: Browser
        @ObservedObject var tab: Tab

        @State private var hovering = false

        var body: some View {
            if !tab.isBlank, let url = tab.address {
                // The whole run up to the doors at the far end, not the text
                // alone: the address is wherever the pointer lands there.
                Button { browser.edit() } label: {
                    HStack(spacing: 0) {
                        Text(Where.site(url))
                            .foregroundStyle(Palette.ink)
                        Text(" / " + tab.label)
                            .foregroundStyle(Palette.muted)
                    }
                    .font(.system(size: 12.5))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 26)
                    .background {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(hovering ? Palette.hover : .clear)
                            // At once, not faded: a fade from .clear passes through dark grey.
                            .animation(nil, value: hovering)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering = $0 }
                .help("Change the address   ⌘L")
                .padding(.horizontal, 6)
            }
        }

        /// The host without its www, as the address field shows it.
        static func site(_ url: URL) -> String {
            let host = url.host() ?? Address.pretty(url)
            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }
    }
}
