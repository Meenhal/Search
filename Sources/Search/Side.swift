import SwiftUI

/// The tabs, down either side instead of across the top.
///
/// The same pieces as the strip — the grey that slides to the tab you picked,
/// the pinned squares, the cross that appears under the pointer — laid out the
/// other way. The traffic lights keep their corner; the column starts under
/// them and the page takes the whole height beside it.
struct SideBar: View {
    @ObservedObject var browser: Browser
    @ObservedObject var prefs: Preferences
    /// On the window's ground, beside the page's card (see CardEdge): the
    /// ground's colour and no edge of its own, the card's edge being the line.
    var onFrame = false

    @Namespace private var pill

    @State private var landing = false
    /// The width the column had when the edge was picked up.
    @State private var grabbed: CGFloat?
    @State private var onEdge = false

    /// A pin, picked up out of the grid — a separate state from the loose
    /// rows above, since the two gestures never happen at once but move on
    /// two different axes.
    /// The neighbouring spaces' own grey, apart from this one's.
    @Namespace private var before
    @Namespace private var after

    @State private var groupFrames: [UUID: CGRect] = [:]
    /// A loose row carried up onto the squares, and the cell it would take:
    /// the squares make way for it there, as in Dia (see carry).
    @State private var pinning: Pinning?
    /// A square carried down out of the grid: drawn as a row under the hand,
    /// and a row again once let go.
    @State private var unpinning: Tab.ID?
    @State private var releaseWatch: Any?

    struct Pinning: Equatable {
        let id: Tab.ID
        var at: Int
        /// The hand, in the grid's own space: the square floats there.
        var point: CGPoint
    }

    // Sized as in Dia: roomier rows and taller pins than the strip's.
    fileprivate static let row: CGFloat = 34
    private static let gap: CGFloat = 3
    private static let square: CGFloat = 40
    private static let pinGap: CGFloat = 6

    private var onRight: Bool { prefs.sidePosition == .right }
    private var innerEdge: Alignment { onRight ? .leading : .trailing }


    var body: some View {
        ZStack(alignment: .top) {
            // Not under the card for a new space: it isn't made of views that
            // would take the click first.
            DragStrip(reserved: 0, below: browser.makingSpace ? .greatestFiniteMagnitude : rowsEnd, onDoubleClick: browser.newTab)

            // The band the lights sit in is this mode's title bar: the window
            // is dragged by it and a double-click fills the screen with it.
            // The lights are the title bar's own and answer first.
            DragStrip()
                .frame(height: Metrics.strip)

            VStack(alignment: .leading, spacing: 0) {
                // The traffic lights' corner. Back, forward and reload are on
                // the page's card, in its address band (AddressBand).
                Color.clear
                    .frame(height: Metrics.strip)

                // The spaces side by side, as pages: two fingers sideways move
                // the one on screen and the next one together, the next one
                // coming in as this one goes, with nothing between them.
                pages

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            // Clear of the foot, which sits over the column's bottom edge.
            .padding(.bottom, SideBar.footHeight)

            VStack {
                Spacer()
                foot
            }
        }
        .frame(width: prefs.sideWidth)
        .frame(maxHeight: .infinity)
        // Rows on their way to or from another space stay in the column.
        .clipped()
        .onAppear { SpaceSwipe.shared.start(for: browser) }
        .background {
            ZStack {
                landing ? Palette.sideHover : onFrame ? Palette.frame : Palette.ground
                if prefs.splitView {
                    SplitDropZone(browser: browser, tab: nil, kind: .strip)
                }
            }
        }
        .overlay(alignment: innerEdge) {
            if !onFrame { Rectangle().fill(Palette.hairline).frame(width: 1) }
        }
        .overlay(alignment: innerEdge) { edge }
        .onDrop(of: [.url, .text], isTargeted: $landing) { providers in
            browser.take(providers)
        }
        .animation(Motion.quick, value: landing)
        .animation(Motion.glide, value: browser.activeID)
        .animation(Motion.glide, value: browser.editingTab)
        .animation(Motion.settle, value: browser.tabs.map(\.id))
        .animation(Motion.settle, value: browser.pinnedCount)
        // The last square made the first row changes nothing in the row's
        // order; only how many of each there are.
        .animation(Motion.settle, value: browser.listedPins.count)
    }

    /// The column's edge: pull it to make the column wider or narrower,
    /// double-click it to put it back. The hairline darkens under the pointer
    /// so the edge says it can be taken before it is.
    private var edge: some View {
        Rectangle()
            .fill(Palette.ink.opacity(onEdge || grabbed != nil ? 0.18 : 0))
            .frame(width: onEdge || grabbed != nil ? 2 : 1)
            .frame(width: 9)
            .contentShape(Rectangle())
            .onHover { over in
                onEdge = over
                if over { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        if grabbed == nil { grabbed = prefs.sideWidth }
                        let delta = onRight ? -value.translation.width : value.translation.width
                        let wanted = (grabbed ?? prefs.sideWidth) + delta
                        prefs.sideWidth = min(Metrics.sideMax, max(Metrics.sideMin, wanted))
                    }
                    .onEnded { _ in grabbed = nil }
            )
            .modifier(OneClick(double: true) {
                withAnimation(Motion.settle) { prefs.sideWidth = Metrics.side }
            })
            .animation(Motion.quick, value: onEdge)
    }

    // MARK: - the spaces, as pages

    /// Where the space on screen sits among them: one past the last while
    /// the card for a new one is up.
    private var spaceAt: Int {
        browser.makingSpace ? browser.spaces.count : (browser.spaces.firstIndex { $0.id == browser.spaceID } ?? 0)
    }

    private var pages: some View {
        let width = prefs.sideWidth
        let swipe = browser.spaceSwipe
        let at = spaceAt
        return ZStack(alignment: .topLeading) {
            page(at, pill: pill)
                .offset(x: swipe)
            // Only while the fingers are bringing one in: the one they are
            // bringing, a page's width away.
            if swipe > 0, at > 0 {
                page(at - 1, pill: before)
                    .offset(x: swipe - width)
            }
            if swipe < 0, at < browser.spaces.count {
                page(at + 1, pill: after)
                    .offset(x: swipe + width)
            }
        }
        // The pages are the column's whole width, each with its own margin.
        .padding(.horizontal, -10)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// One space's page: the rows on screen, another space's rows as they
    /// were left, or past the last the card for a new one.
    @ViewBuilder
    private func page(_ index: Int, pill: Namespace.ID) -> some View {
        Group {
            if index == browser.spaces.count {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    NewSpaceCard(browser: browser)
                    Spacer(minLength: 0)
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
            } else if browser.spaces[index].id == browser.spaceID {
                VStack(alignment: .leading, spacing: 0) {
                    if browser.pinnedCount > 0 {
                        pinned
                            .padding(.bottom, 10)
                    }
                    // A row too long for the window scrolls between the pins
                    // and the foot, rather than running under the lights at one
                    // end and the foot at the other. While it fits it stays a
                    // plain stack, and the space under it is still the
                    // window's to be dragged by. Inside the page: the swipe
                    // between spaces moves the page, scroll and all.
                    ViewThatFits(in: .vertical) {
                        rows
                        ScrollViewReader { proxy in
                            // The scroll view reaches into the margin on
                            // the right and the rows keep it inside, so the
                            // system's bar lands in the margin beside them
                            // rather than over the cross on the tab under the
                            // pointer. The column's edge lies over that margin
                            // and answers first, so the bar never fights the
                            // resize; the wheel and the trackpad still scroll.
                            ScrollView(.vertical) {
                                rows.padding(.trailing, 10)
                            }
                            .padding(.trailing, -10)
                            // The tab you go to is the tab you see — ⌘1–⌘9,
                            // ⇧⌘], a link opening beside the one on screen.
                            .onChange(of: browser.activeID) { _, id in
                                guard let id else { return }
                                let representative = browser.activeSplit?.left ?? id
                                withAnimation(Motion.glide) { proxy.scrollTo(representative) }
                            }
                            .onAppear {
                                if let id = browser.activeID {
                                    proxy.scrollTo(browser.activeSplit?.left ?? id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            } else {
                preview(browser.parked[browser.spaces[index].id] ?? Parked(tabs: [], active: nil), pill: pill)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: prefs.sideWidth, alignment: .topLeading)
    }

    /// Another space's rows, drawn with the same pieces as this one's so the
    /// two read as one column while they pass — and nothing to press until
    /// it is the one on screen.
    private func preview(_ row: Parked, pill: Namespace.ID) -> some View {
        let pins = row.tabs.filter { $0.pin != nil && !($0.listed && prefs.showsPinRows) }
        let listed = prefs.showsPinRows ? row.tabs.filter { $0.pin != nil && $0.listed } : []
        let rest = row.tabs.filter { tab in
            tab.pin == nil && (!prefs.splitView || !row.splits.contains(where: { $0.right == tab.id }))
        }
        let cells = pinCells(pins.count)
        return VStack(alignment: .leading, spacing: 0) {
            if !pins.isEmpty {
                VStack(spacing: 0) {
                    PinGrid(cells: cells) {
                        ForEach(Array(pins.enumerated()), id: \.element.id) { index, tab in
                            PinSquare(browser: browser, prefs: prefs, tab: tab, live: tab.id == row.active,
                                      pill: pill, width: cells[index].width, height: cells[index].height)
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            VStack(spacing: SideBar.gap) {
                ForEach(listed) { tab in
                    SideRow(browser: browser, prefs: prefs, tab: tab, live: tab.id == row.active,
                            pill: pill, close: {}, interactive: false)
                }
                // Groups aren't drawn here, so the line goes over all the rest.
                if showsLine(listed: listed.count, loose: rest.count) {
                    KeepLine(clears: false) {}
                }
                ForEach(rest) { tab in
                    rowItem(tab, tabs: row.tabs, splits: row.splits, activeID: row.active,
                            interactive: false, pill: pill, close: {})
                }
            }
            newTab
        }
        .allowsHitTesting(false)
    }

    /// Where the rows stop and the window's own drag area starts. Added up
    /// from what was drawn rather than measured: a measurement would arrive a
    /// frame late, and for one frame the whole column would drag the window.
    private var rowsEnd: CGFloat {
        let displayed = browser.displayedTabs
        let pins = browser.squarePins.count
        let pinBlock = pins == 0 ? 0 : (pinCells(pins).map(\.maxY).max() ?? 0) + 10
        let listed = browser.listedPins.count
        let ungrouped = displayed.filter { $0.pin == nil && (!prefs.usesTabGroups || browser.group(of: $0) == nil) }.count
        let listBlock = CGFloat(listed) * (SideBar.row + SideBar.gap) + (listed > 0 ? SideBar.gap : 0)
            + (showsLine(listed: listed, loose: ungrouped) ? KeepLine.height + SideBar.gap : 0)
        let rows = prefs.usesTabGroups
            ? displayed.filter { $0.pin == nil && browser.group(of: $0) == nil }
                + browser.tabGroups.flatMap { browser.visibleTabs(in: $0) }
            : displayed.filter { $0.pin == nil }
        // A pair is two lines (see SplitTabItem).
        let pairs = rows.filter { browser.split(for: $0) != nil }.count
        let headings = prefs.usesTabGroups ? CGFloat(browser.tabGroups.count) * (GroupHeading.height + SideBar.gap) : 0
        let loose = CGFloat(rows.count) * (SideBar.row + SideBar.gap) + CGFloat(pairs) * SideBar.row + headings
        return Metrics.strip + pinBlock + listBlock + loose + SideBar.row + 8
    }

    @ViewBuilder
    private func rowItem(
        _ tab: Tab,
        tabs: [Tab],
        splits: [TabSplit],
        activeID: Tab.ID?,
        interactive: Bool,
        pill: Namespace.ID,
        close: @escaping () -> Void
    ) -> some View {
        let pair = prefs.splitView ? splits.first(where: { $0.left == tab.id }) : nil
        if let pair, let right = tabs.first(where: { $0.id == pair.right }) {
            SplitTabItem(browser: browser, prefs: prefs, left: tab, right: right,
                         width: nil, height: SideBar.row,
                         live: activeID.map { pair.contains($0) } ?? false,
                         focusedID: activeID,
                         interactive: interactive, pill: pill)
                .frame(maxWidth: .infinity)
        } else {
            SideRow(browser: browser, prefs: prefs, tab: tab,
                    live: tab.id == activeID, pill: pill, close: close,
                    interactive: interactive)
        }
    }

    // MARK: - the pinned squares

    private var pinnedTabs: [Tab] { browser.squarePins }
    private var looseTabs: [Tab] {
        browser.displayedTabs.filter { $0.pin == nil && (!prefs.usesTabGroups || browser.group(of: $0) == nil) }
    }

    /// The line between what is kept and what comes and goes, with the
    /// pinned rows on: over the tabs Clear would close, or under rows with
    /// nothing below them yet. Not with the rows off, nor with nothing on
    /// either side of it.
    private func showsLine(listed: Int, loose: Int) -> Bool {
        prefs.showsPinRows && listed + loose > 0
    }

    /// How many squares go in each row: at most three — fewer only when the
    /// column is too narrow for three of the classic width — and as even as
    /// they go, the fuller rows first. Four are two and two, five three and
    /// two, seven three, two and two. Every row fills the column's width,
    /// so two pins are two halves and one pin is the whole row.
    static func pinRows(_ count: Int, most: Int) -> [Int] {
        guard count > 0 else { return [] }
        let most = max(1, most)
        let rows = (count + most - 1) / most
        let base = count / rows
        let extra = count % rows
        return (0..<rows).map { $0 < extra ? base + 1 : base }
    }

    /// Where each square goes, in the order of the row. Each row splits the
    /// column's width between its own squares — the row fills edge to edge,
    /// not each cell on its own — and every row is as tall as the narrowest
    /// cell allows, never taller than the classic square: past that a cell
    /// turns into a wide, short button rather than a bigger icon.
    private func pinCells(_ count: Int) -> [CGRect] {
        let room = prefs.sideWidth - 20
        let gap = SideBar.pinGap
        let fits = Int((room + gap) / (SideBar.square + gap))
        let rows = SideBar.pinRows(count, most: min(3, max(1, fits)))
        let widths = rows.map { max(20, (room - CGFloat($0 - 1) * gap) / CGFloat($0)) }
        let height = min(SideBar.square, widths.min() ?? SideBar.square)
        var cells: [CGRect] = []
        for (row, n) in rows.enumerated() {
            for col in 0..<n {
                cells.append(CGRect(x: CGFloat(col) * (widths[row] + gap),
                                    y: CGFloat(row) * (height + gap),
                                    width: widths[row], height: height))
            }
        }
        return cells
    }

    /// The grid itself: each row's cells share the column's width between
    /// them (see pinCells).
    private var pinned: some View {
        let tabs = pinnedTabs
        // A row carried over the squares has a cell of its own among them,
        // the others laid out around it; it is placed last in the grid's list.
        let slot = pinning?.at
        let all = pinCells(tabs.count + (slot == nil ? 0 : 1))
        let cells = slot.map { slot in all.indices.filter { $0 != slot }.map { all[$0] } } ?? all
        let grid = cells + (slot.map { [all[$0]] } ?? [])
        // Measured in the grid's own space, not the square's: a square that
        // has just been moved to a new cell would otherwise report the drag
        // from where it now is, the target would jump back, and the square
        // would shuttle between two cells for as long as the finger stayed.
        return VStack(spacing: 0) { PinGrid(cells: grid) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                PinSquare(
                    browser: browser,
                    prefs: prefs,
                    tab: tab,
                    live: tab.id == browser.activeID,
                    pill: pill,
                    width: cells[index].width,
                    height: cells[index].height
                )
                // On its way out, it is drawn as the row it will be, at the
                // head of the rows (see loose); never swapped for another
                // view here, which would lose the drag under the hand.
                .opacity(unpinning == tab.id ? 0 : 1)
                // The hand's travel is the square's own, as a row's is
                // (Carried): a move redraws the one square being carried,
                // not the column (idea 31).
                .modifier(PinCarried(index: index, cells: cells,
                                     out: { out in
                                         let id: Tab.ID? = out ? tab.id : nil
                                         if unpinning != id { withAnimation(Motion.settle) { unpinning = id } }
                                     },
                                     dropOut: {
                                         SideBar.still {
                                             unpinning = nil
                                             browser.unpin(tab)
                                         }
                                     }) { browser.move(tab, to: $0) })
            }
            // The cell kept open for the carried row: empty, the square
            // itself floats under the hand (below).
            if slot != nil {
                Color.clear
            }
        } }
        // The carried row as a square, lifted over the others and under the
        // hand, as a square carried within the grid is (PinCarried).
        .overlay(alignment: .topLeading) {
            if let pinning, let slot, let tab = browser.tabs.first(where: { $0.id == pinning.id }) {
                let cell = all[slot]
                CarriedSquare(prefs: prefs, tab: tab, width: cell.width, height: cell.height)
                    .shadow(color: .black.opacity(0.16), radius: 10, y: 3)
                    .offset(x: pinning.point.x - cell.width / 2, y: pinning.point.y - cell.height / 2)
                    .transaction { $0.animation = nil }
                    .allowsHitTesting(false)
            }
        }
        .coordinateSpace(name: "pins")
        .background(PinDropZone(browser: browser).padding(.vertical, -6))
        // Let go anywhere, the carrying ends: a drag SwiftUI dropped without
        // telling its end (its view drawn again mid-way) can't leave a cell
        // held open or a pin half out.
        .onAppear {
            guard releaseWatch == nil else { return }
            releaseWatch = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { settleCarrying() }
                return event
            }
        }
        .onDisappear {
            if let releaseWatch { NSEvent.removeMonitor(releaseWatch) }
            releaseWatch = nil
            settleCarrying()
        }
    }

    /// Changes made with no animation at all, not even one already under way.
    static func still(_ change: () -> Void) {
        var quiet = Transaction()
        quiet.disablesAnimations = true
        withTransaction(quiet, change)
    }

    private func settleCarrying() {
        guard pinning != nil || unpinning != nil else { return }
        withAnimation(Motion.settle) {
            pinning = nil
            unpinning = nil
        }
    }

    /// Where the hand is, while a loose row is carried: over the squares,
    /// the cell it would take there; anywhere else, nothing.
    private func carry(_ tab: Tab) {
        let wanted: Pinning? = {
            guard tab.pin == nil, !tab.isBlank, !tab.shy,
                  let point = PinDropZone.point(browser, NSEvent.mouseLocation) else { return nil }
            let cells = pinCells(pinnedTabs.count + 1)
            func distance(_ cell: CGRect) -> CGFloat { hypot(cell.midX - point.x, cell.midY - point.y) }
            let at = cells.indices.min { distance(cells[$0]) < distance(cells[$1]) } ?? cells.count - 1
            return Pinning(id: tab.id, at: at, point: point)
        }()
        guard pinning != wanted else { return }
        // The squares make way with a spring; the hand alone moves nothing else.
        if pinning?.at != wanted?.at || pinning?.id != wanted?.id {
            withAnimation(Motion.settle) { pinning = wanted }
        } else {
            pinning = wanted
        }
    }

    // MARK: - the rows

    /// The pins kept as rows, under the squares: Arc's pinned list. Each is
    /// a row like any other to look at, carried only among its own kind.
    private var listed: some View {
        let pins = browser.listedPins
        let squares = browser.squarePins.count
        return VStack(spacing: SideBar.gap) {
            ForEach(Array(pins.enumerated()), id: \.element.id) { index, tab in
                SideRow(browser: browser, prefs: prefs, tab: tab,
                        live: tab.id == browser.activeID, pill: pill,
                        close: { browser.close(tab) })
                    .modifier(Carried(index: index, count: pins.count,
                                      step: SideBar.row + SideBar.gap, vertical: true,
                                      space: "listed") {
                        browser.moveDisplayedTab(tab, to: $0 + squares)
                    })
            }
        }
        .coordinateSpace(name: "listed")
        .padding(.bottom, pins.isEmpty ? 0 : SideBar.gap)
    }

    private var loose: some View {
        VStack(spacing: SideBar.gap) {
            if prefs.usesTabGroups {
                ForEach(browser.tabGroups) { group in
                    GroupHeading(browser: browser, group: group, dragSpace: "rows")
                    groupRows(group)
                }
            }
            // See the grid: the drag is measured in the column's space, not
            // the row's, so a row that has just moved keeps its bearings.
            // Worked out once, not by every row: each look walks the whole
            // row, and 300 rows asking made redrawing the column quadratic.
            let loose = looseTabs
            // Under the groups: Clear keeps them, as it keeps the pins, so
            // everything above the line is what stays.
            if showsLine(listed: browser.listedPins.count, loose: loose.count) {
                KeepLine(clears: !loose.isEmpty) { browser.clearTabs() }
            }
            // A square carried down out of the grid: the row it will be, where
            // it will land.
            if let id = unpinning, let tab = browser.tabs.first(where: { $0.id == id }) {
                CarriedRow(prefs: prefs, tab: tab, width: prefs.sideWidth - 20)
                    .transition(.opacity)
            }
            ForEach(Array(loose.enumerated()), id: \.element.id) { index, tab in
                let step = SideBar.row + SideBar.gap
                rowItem(tab, tabs: browser.tabs, splits: browser.splits,
                        activeID: browser.activeID, interactive: true, pill: pill,
                        close: { browser.close(tab) })
                // Over the squares it is drawn among them (see pinned), not
                // here; only hidden, never swapped, so the drag stays held.
                .opacity(pinning?.id == tab.id ? 0 : 1)
                // Positions here are among the loose rows; the pinned block
                // sits in front of them in the real list.
                .modifier(Carried(index: index, count: loose.count, step: step, vertical: true,
                                  space: "rows", onDropTab: { source, point in drop(source, at: point) },
                                  outside: { browser.dragOut(tab) }, browser: browser, tab: tab,
                                  onTravel: { carry(tab) }, free: pinning?.id == tab.id,
                                  onRelease: { if pinning != nil { withAnimation(Motion.settle) { pinning = nil } } },
                                  bounded: tab.isBlank || tab.shy) {
                    if prefs.usesTabGroups {
                        browser.move(tab, within: nil, to: $0)
                    } else {
                        browser.moveDisplayedTab(tab, to: $0 + browser.pinnedCount)
                    }
                })
            }
        }
        .coordinateSpace(name: "rows")
        .onPreferenceChange(GroupDropFrames.self) { groupFrames = $0 }
    }

    private func drop(_ tab: Tab, at point: CGPoint) {
        // Carried up onto the squares: pinned, in the cell they made for it,
        // as in Arc and Dia.
        // At once: it is already where it lands, and an animation only sent
        // the live tab's grey travelling from its old row (SideBar.still).
        if let pinning, pinning.id == tab.id {
            SideBar.still {
                self.pinning = nil
                browser.pin(tab)
                browser.move(tab, to: pinning.at)
            }
            return
        }
        guard prefs.usesTabGroups, tab.pin == nil else { return }
        if let id = groupFrames.first(where: { $0.value.contains(point) })?.key {
            browser.move(tab, toGroup: id)
        }
    }

    private func groupRows(_ group: TabGroup) -> some View {
        let members = browser.visibleTabs(in: group)
        return VStack(spacing: SideBar.gap) {
            ForEach(Array(members.enumerated()), id: \.element.id) { index, tab in
                rowItem(tab, tabs: browser.tabs, splits: browser.splits,
                        activeID: browser.activeID, interactive: true, pill: pill,
                        close: { browser.close(tab) })
                    .padding(.leading, 14)
                    .modifier(Carried(index: index, count: members.count,
                                      step: SideBar.row + SideBar.gap, vertical: true,
                                      space: "rows", onDropTab: { source, point in drop(source, at: point) },
                                      outside: { browser.dragOut(tab) }, browser: browser, tab: tab) {
                        browser.move(tab, within: group.id, to: $0)
                    })
            }
        }
    }

    /// The pinned rows, the loose tabs and the row that makes another,
    /// which scroll as one.
    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            listed
            loose
            newTab
        }
    }

    /// The foot's door and its margin beneath.
    private static let footHeight: CGFloat = 26 + 10

    private var newTab: some View {
        Quiet(icon: "plus", title: "New tab", height: SideBar.row) { browser.newTab() }
            .padding(.top, SideBar.gap)
    }

    /// One small door at the bottom: the settings.
    private var foot: some View {
        SideFoot(browser: browser, prefs: prefs)
    }

}

/// The row at the bottom of the column: the space's door. The extensions,
/// bookmarks and downloads are at the far end of the page's address band
/// (AddressBand).
private struct SideFoot: View {
    @ObservedObject var browser: Browser
    @ObservedObject var prefs: Preferences

    var body: some View {
        HStack(spacing: 2) {
            if prefs.usesSpaces { SpaceDot(browser: browser) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }
}

/// Where the squares are, for a tab carried up onto them (SideBar.drop). The
/// drag is measured among the rows, which scroll; the squares don't, and sit
/// outside the rows' space. So, as for Split View (TabDrag), a view that
/// takes no clicks marks the place, and the drop asks it about the pointer.
private struct PinDropZone: NSViewRepresentable {
    let browser: Browser

    @MainActor private static var zones: [ObjectIdentifier: Weak] = [:]
    private final class Weak { weak var view: NSView?; init(_ view: NSView) { self.view = view } }

    final class Zone: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    func makeNSView(context: Context) -> Zone {
        let zone = Zone()
        PinDropZone.zones[ObjectIdentifier(browser)] = Weak(zone)
        return zone
    }

    func updateNSView(_ zone: Zone, context: Context) {
        PinDropZone.zones[ObjectIdentifier(browser)] = Weak(zone)
    }

    /// `point`, on the screen, in the grid's own space (its top left, y
    /// down) when it is over this window's squares; nil anywhere else.
    @MainActor static func point(_ browser: Browser, _ point: NSPoint) -> CGPoint? {
        guard let zone = zones[ObjectIdentifier(browser)]?.view, let window = zone.window,
              window === browser.window else { return nil }
        let local = zone.convert(window.convertPoint(fromScreen: point), from: nil)
        guard zone.bounds.contains(local) else { return nil }
        let down = zone.isFlipped ? local.y : zone.bounds.height - local.y
        // The zone reaches 6 points past the grid above and below.
        return CGPoint(x: local.x, y: down - 6)
    }
}

/// A loose row carried over the squares, drawn as one of them in the cell
/// it would take.
private struct CarriedSquare: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var tab: Tab
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let scale = min(width, height)
        Group {
            if prefs.glyph == .icons, let icon = tab.icon {
                Mark(icon: icon, letter: tab.monogram, size: scale * 16 / 34)
            } else {
                Text(tab.monogram)
                    .font(.system(size: scale * 12 / 34, weight: .medium))
                    .foregroundStyle(Palette.ink)
            }
        }
        .frame(width: width, height: height)
        .background(Palette.sideWash, in: RoundedRectangle(cornerRadius: scale * 9 / 34, style: .continuous))
    }
}

/// A square carried down out of the grid, drawn as the row it will become,
/// at the head of the rows where it will land.
private struct CarriedRow: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject var tab: Tab
    let width: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            if prefs.glyph == .icons, let icon = tab.icon {
                Mark(icon: icon, letter: tab.monogram, size: 15)
            }
            Text(tab.label)
                .font(.system(size: 13))
                .lineLimit(1)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: SideBar.row, alignment: .leading)
        .background(Palette.sideWash, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// The pinned squares' grid, every cell laid out at once. A lazy grid makes
/// its cells only once the column is on screen, where the column's slide
/// can't take them along: folded with ⌘S and brought back, the squares stood
/// in place while the column came in beneath them. A dozen squares need no
/// laziness.
private struct PinGrid: Layout {
    /// Each square's place, worked out by the column (see pinCells).
    let cells: [CGRect]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: cells.map(\.maxX).max() ?? 0, height: cells.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, subview) in subviews.enumerated() where cells.indices.contains(index) {
            let cell = cells[index]
            subview.place(
                at: CGPoint(x: bounds.minX + cell.minX, y: bounds.minY + cell.minY),
                proposal: ProposedViewSize(width: cell.width, height: cell.height)
            )
        }
    }
}

/// A pinned tab as a cell in the block at the top of the column — as wide as
/// its row asks for, but never taller than the classic square, so a row with
/// room to spare turns into a wide, short button rather than a bigger icon.
private struct PinSquare: View {
    @ObservedObject var browser: Browser
    @ObservedObject var prefs: Preferences
    @ObservedObject var tab: Tab
    let live: Bool
    let pill: Namespace.ID
    var width: CGFloat = 34
    var height: CGFloat = 34

    @State private var hovering = false

    /// Everything drawn inside scales off the shorter edge — the one that
    /// stays put — so the glyph sits at its usual size, centred, rather than
    /// stretching to chase the width.
    private var scale: CGFloat { min(width, height) }

    /// The site's colour, for the live square, when it is drawn as its icon.
    private var tint: Color? {
        guard prefs.glyph == .icons, let icon = tab.icon, let colour = IconTint.colour(of: icon) else { return nil }
        return Color(nsColor: colour)
    }

    var body: some View {
        Group {
            if browser.editingPin == tab.id {
                PinField(browser: browser, tab: tab)
            } else if tab.loading {
                // Its page on the way, as a row's ring says.
                Ring(size: scale * 11 / 34)
            } else if prefs.glyph == .icons, let icon = tab.icon {
                Mark(icon: icon, letter: tab.pin ?? "", size: scale * 16 / 34, dim: tab.asleep)
            } else {
                Text(tab.pin ?? "")
                    .font(.system(size: scale * 12 / 34, weight: .medium))
                    .foregroundStyle((live ? Palette.ink : Palette.muted).opacity(tab.asleep ? 0.45 : 1))
            }
        }
        .frame(width: scale * 16 / 34, height: scale * 16 / 34)
        .frame(width: width, height: height)
        .background {
            if live {
                // Filled with the site's own colour, as in Dia, when its icon
                // has one (IconTint). Otherwise darker than the resting
                // squares' grey by as much as a live row is darker than the
                // white it sits on (Drice: the live pin barely showed among
                // the others).
                RoundedRectangle(cornerRadius: scale * 9 / 34, style: .continuous)
                    .fill(tint ?? Palette.sidePinLive)
                    .overlay {
                        if tint != nil {
                            RoundedRectangle(cornerRadius: scale * 9 / 34, style: .continuous)
                                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
                        }
                    }
                    .matchedGeometryEffect(id: "live", in: pill)
            } else {
                RoundedRectangle(cornerRadius: scale * 9 / 34, style: .continuous)
                    .fill(tab.asleep
                          ? (hovering ? Palette.sideHover : Palette.sideTile)
                          : (hovering ? Palette.sideTileOpenHover : Palette.sideTileOpen))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: scale * 9 / 34, style: .continuous))
        .modifier(OneClick(double: live) {
            if live { browser.goHome(tab) } else { browser.select(tab) }
        })
        // Put down, like ⌘W: close() is what knows a pin isn't removed.
        .overlay { MiddleClick { browser.close(tab) } }
        .onHover { hovering = $0 }
        .contextMenu { TabMenu(browser: browser, tab: tab, close: { browser.close(tab) }) }
        .help(tab.label)
        .animation(Motion.quick, value: hovering)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}

/// One tab, as a line in the column.
private struct SideRow: View {
    @ObservedObject var browser: Browser
    @ObservedObject var prefs: Preferences
    @ObservedObject var tab: Tab
    let live: Bool
    let pill: Namespace.ID
    let close: () -> Void
    var interactive = true

    @State private var hovering = false
    @State private var shake: CGFloat = 0

    private var editing: Bool { browser.editingTab == tab.id }

    /// The ring or the speaker, which stay for as long as the page loads or
    /// plays (or is muted) and so keep a place of their own at the end of the
    /// row. The cross is only there under the pointer, and takes none.
    private var status: Bool { !editing && (tab.loading || speaker) }
    /// The speaker, which can be pressed, and so steps in beside the cross
    /// under the pointer rather than hiding beneath it as the ring does.
    private var speaker: Bool { !tab.loading && (tab.noisy || tab.muted) }

    var body: some View {
        HStack(spacing: 8) {
            if editing {
                TabAddressField(browser: browser)
                    .frame(height: 16)
            } else {
                if prefs.glyph == .icons, !tab.isBlank {
                    Mark(icon: tab.icon, letter: tab.monogram, size: 15)
                }
                if tab.bench {
                    // A script's tab, not yours.
                    Image(systemName: "flask")
                        .font(.system(size: 9))
                        .foregroundStyle(colour.opacity(0.7))
                }
                if tab.shy {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 9))
                        .foregroundStyle(colour.opacity(0.7))
                }
                if tab.recording {
                    // An extension recording from this page (RecordingIndicator).
                    Image(systemName: "record.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(colour.opacity(0.8))
                        .help("Recording")
                }
                Text(tab.label)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(colour)
            }

            if status {
                Spacer(minLength: 2)

                ZStack {
                    if tab.loading {
                        Ring().transition(.opacity)
                    } else {
                        Speaker(tab: tab).transition(.opacity)
                    }
                }
                .frame(width: 15, height: 15)
                // The cross takes this place while the pointer is here; the
                // speaker moves one place in, clear of the cross's reach.
                .opacity(hovering && !speaker ? 0 : 1)
                .padding(.trailing, hovering && speaker ? 28 : 0)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, status ? 7 : 10)
        .frame(height: SideBar.row)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The title keeps its length under the pointer and fades out
        // beneath the cross, rather than being cut shorter, so its end
        // doesn't jump on each row the pointer passes.
        .mask {
            ZStack {
                Rectangle().opacity(hovering && !editing && !status ? 0 : 1)
                HStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 16)
                    Color.clear.frame(width: 32)
                }
            }
        }
        .overlay(alignment: .trailing) {
            if !editing {
                ZStack {
                    if hovering {
                        // A pinned row is put down, not closed (see
                        // Browser.close), and says so, as Arc's does.
                        // As large as Dia's: a glyph you can read and a
                        // square you can aim at.
                        Image(systemName: tab.pin != nil ? "minus" : "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.ink.opacity(0.75))
                            .frame(width: 24, height: 24)
                            .background(Palette.ink.opacity(0.07), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .transition(.opacity)
                    }
                }
                .frame(width: 24, height: 24)
                .overlay {
                    Color.clear
                        .frame(width: 30, height: SideBar.row)
                        .contentShape(Rectangle())
                        .onTapGesture { if hovering { close() } }
                }
                .padding(.trailing, 5)
            }
        }
        .animation(Motion.quick, value: tab.loading)
        .animation(Motion.quick, value: speaker)
        .background { ground }
        .modifier(Shake(travel: shake))
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .modifier(OneClick(double: false) {
            guard interactive else { return }
            if live { browser.beginTabEdit(tab) } else { browser.select(tab) }
        })
        .overlay { if interactive { MiddleClick(act: close) } }
        .onHover { hovering = $0 }
        .contextMenu { if interactive { TabMenu(browser: browser, tab: tab, close: close) } }
        .background {
            if interactive && prefs.splitView {
                SplitDropZone(browser: browser, tab: tab, kind: .strip)
            }
        }
        .animation(Motion.quick, value: hovering)
        .animation(Motion.glide, value: editing)
        .onChange(of: browser.refusals) { _, _ in
            guard editing else { return }
            shake = 0
            withAnimation(.easeOut(duration: 0.5)) { shake = 1 }
        }
        .transition(.scale(scale: 0.94, anchor: .leading).combined(with: .opacity))
    }

    @ViewBuilder
    private var ground: some View {
        if live {
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.sideWash)
                if prefs.showsReading {
                    GeometryReader { geo in
                        ReadingFill(meter: tab.meter, width: geo.size.width)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .matchedGeometryEffect(id: "live", in: pill)
        } else if hovering {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Palette.sideHover)
        }
    }

    private var colour: Color {
        if live { return Palette.ink }
        return hovering ? Palette.ink.opacity(0.7) : Palette.muted
    }
}

/// A row that is an action rather than a page. Quiet until the pointer is on it.
struct Quiet: View {
    let icon: String
    let title: LocalizedStringResource
    var height: CGFloat = 28
    let act: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: act) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 15)
                Text(title)
                    .font(.system(size: 13))
                Spacer(minLength: 0)
            }
            .foregroundStyle(hovering ? Palette.ink.opacity(0.7) : Palette.faint)
            .padding(.leading, 10)
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(hovering ? Palette.sideHover : .clear)
                    // At once, not faded: a fade from .clear passes through dark grey.
                    .animation(nil, value: hovering)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}

/// The line between what is kept and the tabs that come and go, as Arc
/// draws it over its Today tabs, with Clear at its end under the pointer:
/// the tabs below it closed, everything above it left as it was.
struct KeepLine: View {
    static let height: CGFloat = 18
    /// Whether there is anything under it to clear.
    let clears: Bool
    let act: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 1)
            if clears && hovering {
                Button(action: act) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8, weight: .semibold))
                        Text("Clear")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Palette.muted)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close the tabs under the line. Pins and groups stay; ⇧⌘T brings them all back.")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: KeepLine.height)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}

/// The speaker at the end of a tab that plays sound, or that was muted and
/// so says it is: a press mutes the tab or lets it be heard again. Drawn as
/// it was before it could be pressed, with the cross's faint disc behind
/// it only while the pointer is on it.
struct Speaker: View {
    @ObservedObject var tab: Tab

    @State private var hovering = false

    var body: some View {
        Button(action: tab.toggleMute) {
            Image(systemName: tab.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 8))
                .foregroundStyle(Palette.muted)
                .frame(width: 15, height: 15)
                .background(Palette.ink.opacity(hovering ? 0.07 : 0), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(tab.muted ? "Unmute Tab" : "Mute Tab")
        .animation(Motion.quick, value: hovering)
    }
}

/// A small square holding one symbol. Lit when what it opens is open.
struct Door: View {
    let icon: String
    var on = false
    var help: LocalizedStringResource = ""
    let act: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: act) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(on ? Palette.ink : (hovering ? Palette.ink.opacity(0.7) : Palette.muted))
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(on ? Palette.sideWash : (hovering ? Palette.sideHover : .clear))
                        // At once, not faded: a fade from .clear passes through dark grey.
                        .animation(nil, value: hovering)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(Text(help))
        .animation(Motion.quick, value: hovering)
        .animation(Motion.quick, value: on)
    }
}

/// A pinned square picked up and carried across the grid, its travel its
/// own: only the square being carried redraws as the hand moves, and the
/// grid only when it changes place.
struct PinCarried: ViewModifier {
    let index: Int
    let cells: [CGRect]
    /// Carried below the grid, or back into it.
    var out: ((Bool) -> Void)? = nil
    /// Let go below the grid: the pin is to be a row again.
    var dropOut: (() -> Void)? = nil
    let move: (Int) -> Void

    @State private var held = false
    @State private var from = 0
    @State private var travel: CGSize = .zero
    @State private var below = false

    private var shift: CGSize { PinCarried.offset(travel: travel, from: from, index: index, cells: cells) }
    /// Whether the hand still holds it, reset by SwiftUI even when the drag
    /// is dropped without its end being told.
    @GestureState private var pressing = false

    func body(content: Content) -> some View {
        content
            .offset(held ? shift : .zero)
            // Under the hand exactly, as a row is (see Carried).
            .transaction { if held { $0.animation = nil } }
            .zIndex(held ? 1 : 0)
            .shadow(color: .black.opacity(held ? 0.16 : 0), radius: 10, y: 3)
            // Measured in the grid's own space, not the square's: a square
            // that has just been moved to a new cell would otherwise report
            // the drag from where it now is, and shuttle between two cells.
            .gesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .named("pins"))
                    .updating($pressing) { _, pressing, _ in pressing = true }
                    .onChanged { value in
                        if !held {
                            held = true
                            from = index
                        }
                        travel = value.translation
                        // Past the grid's foot by half a row: on its way out.
                        let foot = cells.map(\.maxY).max() ?? 0
                        let now = out != nil && value.location.y > foot + 16
                        if now != below {
                            below = now
                            out?(now)
                        }
                        guard !below else { return }
                        let target = PinCarried.target(travel: travel, from: from, cells: cells)
                        if target != index {
                            withAnimation(Motion.settle) { move(target) }
                        }
                    }
                    .onEnded { _ in
                        if below {
                            below = false
                            dropOut?()
                        }
                        withAnimation(Motion.settle) {
                            held = false
                            travel = .zero
                        }
                    }
            )
            .onChange(of: pressing) { _, pressing in
                guard !pressing, held else { return }
                if below {
                    below = false
                    out?(false)
                }
                withAnimation(Motion.settle) {
                    held = false
                    travel = .zero
                }
            }
    }

    /// The held square stays glued to the fingers; every other square is
    /// already where it belongs, because the move put it there. This only
    /// takes off what the held square got for free by changing cell under
    /// its own drag.
    static func offset(travel: CGSize, from: Int, index: Int, cells: [CGRect]) -> CGSize {
        guard cells.indices.contains(from), cells.indices.contains(index) else { return .zero }
        let start = cells[from], now = cells[index]
        return CGSize(width: travel.width - (now.midX - start.midX), height: travel.height - (now.midY - start.midY))
    }

    /// The cell the held square is over: the one whose centre is nearest to
    /// where the fingers have taken the square's own centre. Rows of
    /// different lengths have cells of different widths, so a count of
    /// steps along one axis would land in the wrong one.
    static func target(travel: CGSize, from: Int, cells: [CGRect]) -> Int {
        guard cells.indices.contains(from) else { return 0 }
        let start = cells[from]
        let point = CGPoint(x: start.midX + travel.width, y: start.midY + travel.height)
        func distance(_ cell: CGRect) -> CGFloat { hypot(cell.midX - point.x, cell.midY - point.y) }
        return cells.indices.min { distance(cells[$0]) < distance(cells[$1]) } ?? from
    }
}
