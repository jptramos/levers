import SwiftUI

/// Holds the switches and the user's layout (order + which are hidden).
///
/// Switch *state* is never stored here: `refresh()` just bumps a counter
/// so SwiftUI re-renders and every row calls `isOn` again.
/// The *layout* is stored in UserDefaults (this app's own plist in
/// ~/Library/Preferences/io.github.jptramos.levers.plist) as two lists of ids.
@MainActor
final class SwitchBoard: ObservableObject {
    private let all: [any Switch] = [
        KeepAwakeSwitch(),
        DarkModeSwitch(),
        HideDesktopIconsSwitch(),
        LockKeyboardSwitch(),
    ]
    @Published private(set) var tick = 0
    @Published var lastError: String?
    @Published var lastErrorSettings: URL?
    @Published var editing = false

    // Edit-mode drag state: which row, and how far it sits from its slot.
    // `dragBase` absorbs each swap so the row stays glued to the cursor.
    // (Kept here, not in @State: with a macOS 26 target @State is a Swift
    // macro whose plugin ships only with Xcode, not the Command Line Tools.)
    @Published var dragID: String?
    @Published var dragOffset: CGFloat = 0
    var dragBase: CGFloat = 0

    @Published private(set) var order: [String] { didSet { save() } }
    @Published private(set) var hidden: Set<String> { didSet { save() } }

    private let defaults = UserDefaults.standard
    private enum Key { static let order = "switchOrder", hidden = "hiddenSwitches" }

    init() {
        let ids = all.map(\.id)
        let saved = UserDefaults.standard.stringArray(forKey: Key.order) ?? []
        // Keep the saved order, drop ids that no longer exist, and append
        // switches added in a newer build at the end.
        order = saved.filter(ids.contains) + ids.filter { !saved.contains($0) }
        hidden = Set(UserDefaults.standard.stringArray(forKey: Key.hidden) ?? [])
    }

    /// Every switch, in the user's order (edit mode shows all of them).
    var ordered: [any Switch] {
        order.compactMap { id in all.first { $0.id == id } }
    }

    /// Only the switches the user chose to show.
    var visible: [any Switch] {
        ordered.filter { !hidden.contains($0.id) }
    }

    func refresh() { tick += 1 }

    func set(_ s: any Switch, on: Bool) {
        do {
            try s.set(on: on)
            lastError = nil
            lastErrorSettings = nil
        } catch {
            lastError = "\(s.name): \(error.localizedDescription)"
            lastErrorSettings = (error as? SwitchError)?.settings
        }
        refresh()
    }

    func setHidden(_ s: any Switch, _ hide: Bool) {
        // Background switches stop when hidden, so nothing runs unseen.
        if hide, s.stopsWhenHidden, s.isOn { set(s, on: false) }
        if hide { hidden.insert(s.id) } else { hidden.remove(s.id) }
    }

    /// Move a shown switch `steps` places up (−) or down (+) among the
    /// *shown* switches. Hidden ones keep their slots in `order`.
    /// Returns how many places it actually moved (clamped at the ends).
    @discardableResult
    func moveShown(_ id: String, by steps: Int) -> Int {
        let shown = visible.map(\.id)
        guard let i = shown.firstIndex(of: id) else { return 0 }
        let j = min(max(i + steps, 0), shown.count - 1)
        guard j != i else { return 0 }
        let target = shown[j]
        order.removeAll { $0 == id }
        let t = order.firstIndex(of: target)!
        order.insert(id, at: j > i ? t + 1 : t)
        return j - i
    }

    /// Launch at Login lives with the board so it shares `refresh()` and
    /// `lastError`, but it is an app setting, not a switch: no row, no
    /// reorder, no hiding.
    func setLaunchAtLogin(_ on: Bool) {
        do {
            try LoginItem.set(on: on)
            lastError = nil
        } catch {
            lastError = "Launch at Login: \(error.localizedDescription)"
        }
        refresh()
    }

    private func save() {
        defaults.set(order, forKey: Key.order)
        defaults.set(Array(hidden).sorted(), forKey: Key.hidden)
    }

    /// Test hooks:
    /// `Levers --status` prints each switch's live state, the layout, and exits.
    /// `Levers --on keep-awake` / `--off dark-mode` flips a switch at launch.
    /// `Levers --login on|off` registers / unregisters the login item and exits.
    func applyLaunchArguments() {
        let args = CommandLine.arguments
        if args.contains("--status") {
            for s in ordered {
                print("\(s.id)=\(s.isOn ? "on" : "off")\(hidden.contains(s.id) ? " (hidden)" : "")")
            }
            print("launch-at-login=\(LoginItem.statusText)")
            print("accessibility=\(Permissions.accessibility)")
            print("automation-system-events=\(Permissions.automation)")
            exit(0)
        }
        if let i = args.firstIndex(of: "--login"), i + 1 < args.count {
            setLaunchAtLogin(args[i + 1] == "on")
            print(lastError ?? "launch-at-login=\(LoginItem.statusText)")
            exit(lastError == nil ? 0 : 1)
        }
        for (flag, on) in [("--on", true), ("--off", false)] {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count,
                  let s = all.first(where: { $0.id == args[i + 1] }) else { continue }
            set(s, on: on)
            if let lastError { print(lastError) }
        }
    }
}

/// Right-click actions shared by both row kinds: the non-drag way to
/// hide and reorder (HIG: offer alternatives to drag and drop).
struct RowMenu: View {
    let item: any Switch
    @ObservedObject var board: SwitchBoard

    var body: some View {
        let shown = !board.hidden.contains(item.id)
        if shown {
            Button("Move Up") { withAnimation(.snappy) { board.moveShown(item.id, by: -1) } }
            Button("Move Down") { withAnimation(.snappy) { board.moveShown(item.id, by: 1) } }
            Divider()
        }
        Button(shown ? "Hide \(item.name)" : "Show \(item.name)") {
            withAnimation(.snappy) { board.setHidden(item, shown) }
        }
    }
}

/// A normal row: icon, name, live toggle, on a glass capsule.
struct SwitchRow: View {
    let item: any Switch
    @ObservedObject var board: SwitchBoard

    var body: some View {
        // Reading `tick` makes this row re-render (and re-read isOn) on every
        // refresh *without* changing its identity, so the toggle can still
        // animate its slide.
        let _ = board.tick
        let on = item.isOn  // read live from the system on every render
        HStack {
            Image(systemName: on ? item.onIcon : item.offIcon)
                .font(.system(size: RowMetrics.iconSize))
                .frame(width: RowMetrics.iconColumn)
                .accessibilityHidden(true)  // decorative; the toggle carries the meaning
            Text(item.name).font(.system(size: RowMetrics.nameSize))
            Spacer()
            // A real label for VoiceOver ("Keep Awake, switch, off"), hidden
            // visually because the Text already shows the name.
            Toggle(item.name, isOn: Binding(
                get: { on },
                set: { board.set(item, on: $0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()  // regular size: the 44pt rows have room for it
        }
        .glassRow()
        .contextMenu { RowMenu(item: item, board: board) }
    }
}

/// An edit-mode row. Shown rows: gray − to hide, ≡ handle, draggable.
/// Hidden rows: green + to show.
struct EditRow: View {
    let item: any Switch
    let shown: Bool
    @ObservedObject var board: SwitchBoard

    var body: some View {
        HStack {
            Button {
                withAnimation(.snappy) { board.setHidden(item, shown) }
            } label: {
                // Gray, not red: red − means "delete" on Apple platforms,
                // and hiding is safe and undoable.
                Image(systemName: shown ? "minus.circle.fill" : "plus.circle.fill")
                    .foregroundStyle(.white, shown ? Color.secondary : Color.green)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(shown ? "Hide \(item.name)" : "Show \(item.name)")
            .accessibilityLabel(shown ? "Hide \(item.name)" : "Show \(item.name)")

            Image(systemName: item.offIcon)
                .font(.system(size: RowMetrics.iconSize))
                .frame(width: RowMetrics.iconColumn)
                .accessibilityHidden(true)
            Text(item.name).font(.system(size: RowMetrics.nameSize))
            Spacer()
            if shown {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .glassRow()
        .contextMenu { RowMenu(item: item, board: board) }
        // VoiceOver users reorder with actions instead of dragging.
        .accessibilityAction(named: "Move Up") { board.moveShown(item.id, by: -1) }
        .accessibilityAction(named: "Move Down") { board.moveShown(item.id, by: 1) }
    }
}

/// Panel sizing in one place: 340pt panel,
/// 44pt rows (Apple's minimum comfortable hit target), 17pt icons,
/// 14pt names, regular-size toggles.
enum RowMetrics {
    static let panelWidth: CGFloat = 340
    static let height: CGFloat = 44
    static let spacing: CGFloat = 8
    static let iconSize: CGFloat = 17
    static let iconColumn: CGFloat = 26
    static let nameSize: CGFloat = 14
    static var pitch: CGFloat { height + spacing }  // distance between row centers
}

extension View {
    /// One row = one Liquid Glass capsule (macOS 26+).
    func glassRow() -> some View {
        self
            .padding(.horizontal, 14)
            .frame(height: RowMetrics.height)  // same height in both modes: no layout jump
            .contentShape(Capsule())  // the whole capsule is the drag target
            .glassEffect(.regular, in: Capsule())
    }
}

struct PanelView: View {
    @ObservedObject var board: SwitchBoard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            // GlassEffectContainer groups nearby glass shapes so they render
            // (and blend) together; glass can't sample other glass.
            GlassEffectContainer(spacing: RowMetrics.spacing) {
                if board.editing { editList } else { switchList }
            }

            if let err = board.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = board.lastErrorSettings {
                    Button("Open Settings…") { NSWorkspace.shared.open(url) }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(width: RowMetrics.panelWidth)
        .onAppear { board.refresh() }  // re-read every time the panel opens
    }

    /// Title + Edit/Done at the top right (HIG: editing controls sit with
    /// the list they edit, apart from app-level actions like Quit).
    private var header: some View {
        HStack {
            Text("Levers").font(.title3.weight(.semibold))
            Spacer()
            if board.editing {
                Button("Done") { toggleEditing() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)  // Return
                // Esc also leaves edit mode. An invisible button carries the shortcut.
                Button("Cancel") { toggleEditing() }
                    .keyboardShortcut(.cancelAction)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .accessibilityHidden(true)
            } else {
                Button("Edit") { toggleEditing() }
                    .buttonStyle(.borderless)
            }
        }
    }

    /// App settings + Quit. A checkbox, not a switch: it changes Levers
    /// itself, so it shouldn't look like one of the system levers above.
    private var footer: some View {
        let _ = board.tick  // re-read login status on every refresh
        return VStack(alignment: .leading, spacing: 6) {
            Toggle("Launch at Login", isOn: Binding(
                get: { LoginItem.isOn },
                set: { board.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.checkbox)
            if LoginItem.needsApproval {
                // Registered, but switched off in System Settings.
                Button("Turned off in Login Items. Open Settings…") { LoginItem.openSettings() }
                    .buttonStyle(.link)
                    .font(.caption)
            }
            Button("Quit Levers") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
        }
    }

    private func toggleEditing() {
        withAnimation(.snappy) { board.editing.toggle() }
        board.dragID = nil
        board.refresh()
    }

    private var switchList: some View {
        VStack(spacing: RowMetrics.spacing) {
            ForEach(board.visible, id: \.id) { s in
                SwitchRow(item: s, board: board)
            }
            if board.visible.isEmpty {
                placeholder("All switches hidden. Click Edit to show some.")
            }
        }
    }

    private var editList: some View {
        let shown = board.visible
        let hiddenOnes = board.ordered.filter { board.hidden.contains($0.id) }
        return VStack(alignment: .leading, spacing: RowMetrics.spacing) {
            sectionLabel("Shown")
            ForEach(shown, id: \.id) { s in
                let lifted = board.dragID == s.id
                EditRow(item: s, shown: true, board: board)
                    // The real row follows the cursor, lifted above the others.
                    .scaleEffect(lifted ? 1.04 : 1)
                    .shadow(color: .black.opacity(lifted ? 0.18 : 0), radius: 8, y: 4)
                    .offset(y: lifted ? board.dragOffset : 0)
                    .zIndex(lifted ? 1 : 0)
                    // The lifted row must not animate its own moves, or it
                    // lags behind the cursor; the others animate aside.
                    .transaction { if lifted { $0.animation = nil } }
                    .gesture(reorderGesture(for: s.id))
            }
            if shown.isEmpty { placeholder("Click + to show a switch") }

            if !hiddenOnes.isEmpty {
                sectionLabel("Hidden").padding(.top, 4)
                ForEach(hiddenOnes, id: \.id) { s in
                    EditRow(item: s, shown: false, board: board)
                }
            }
        }
    }

    /// DragGesture reorder: no system drag session, so no start delay.
    /// Each time the row crosses half a row, it swaps one slot.
    private func reorderGesture(for id: String) -> some Gesture {
        // .global, not .local: the row's own frame moves on every swap, which
        // would make the measured translation jump by a whole row.
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { value in
                if board.dragID != id {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { board.dragID = id }
                    board.dragBase = 0
                }
                board.dragOffset = value.translation.height - board.dragBase
                // Swap once the row is past half a neighbor, plus a little
                // slack so hovering near the midpoint doesn't flicker.
                let threshold = RowMetrics.pitch / 2 + 4
                guard abs(board.dragOffset) > threshold else { return }
                let steps = board.dragOffset > 0 ? 1 : -1
                var moved = 0
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    moved = board.moveShown(id, by: steps)
                }
                if moved != 0 {
                    board.dragBase += CGFloat(moved) * RowMetrics.pitch
                    board.dragOffset = value.translation.height - board.dragBase
                    // A light tick on the trackpad for each slot passed.
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    board.dragOffset = 0
                    board.dragID = nil
                }
                board.dragBase = 0
            }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    /// Empty state: a dashed row where switches would be.
    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: RowMetrics.height)
            .overlay(
                Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.tertiary)
            )
    }
}

@main
struct LeversApp: App {
    @StateObject private var board = SwitchBoard()

    init() {
        // @StateObject isn't ready inside init; defer the test hook one runloop turn.
        DispatchQueue.main.async { [board = _board] in
            board.wrappedValue.applyLaunchArguments()
        }
    }

    var body: some Scene {
        // MenuBarExtra (macOS 13+) = an NSStatusItem managed by SwiftUI.
        // `.window` style shows a small panel instead of a plain menu.
        MenuBarExtra {
            PanelView(board: board)
        } label: {
            Image(nsImage: MenuBarGlyph.image)
        }
        .menuBarExtraStyle(.window)
    }
}
