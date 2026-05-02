import SwiftUI

struct SwitchView: View {
    @ObservedObject var model: SwitchModel
    var onCommit: () -> Void = {}

    /// Cursor must move at least this far from the panel-open position before
    /// a hover counts as intentional. Was: a static cursor parked over a tile
    /// at panel-open hijacked the keyboard's default selection.
    private static let hoverThreshold: CGFloat = 10

    @State private var openCursor: CGPoint?

    private var grid: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Design.tilePadding), count: Design.columns)
    }

    var body: some View {
        ZStack {
            VisualEffectBackdrop()
            VStack(spacing: 0) {
                ScrollView {
                    LazyVGrid(columns: grid, spacing: Design.tilePadding) {
                        ForEach(Array(model.windows.enumerated()), id: \.element.id) { idx, win in
                            Tile(window: win, selected: idx == model.selected)
                                .onTapGesture {
                                    model.selected = idx
                                    onCommit()
                                }
                                .onHover { inside in
                                    guard inside else { return }
                                    if let open = openCursor,
                                       let cur = NSEvent.mouseLocation as CGPoint?,
                                       hypot(cur.x - open.x, cur.y - open.y) < Self.hoverThreshold {
                                        return
                                    }
                                    model.selected = idx
                                }
                        }
                    }
                    .padding(Design.tilePadding)
                }
                hintStrip
            }
        }
        .frame(width: Design.panelWidth, height: Design.panelHeight)
        .onAppear { openCursor = NSEvent.mouseLocation }
        .onKeyPress(.tab) { model.advance(); return .handled }
        .onKeyPress(.leftArrow) { model.back(); return .handled }
        .onKeyPress(.rightArrow) { model.advance(); return .handled }
        .onKeyPress(.return) { onCommit(); return .handled }
        .onKeyPress(.escape) { onCommit(); return .handled }
    }

    private var hintStrip: some View {
        HStack(spacing: 14) {
            if !model.filter.isEmpty {
                Text(model.filter)
                    .font(.system(.callout, design: .monospaced))
                Spacer()
            } else {
                Spacer()
            }
            Text("return / esc / type / ⇧")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

private struct Tile: View {
    let window: WindowInfo
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(Color.gray.opacity(0.18))
                .aspectRatio(16.0/10.0, contentMode: .fit)
                .overlay(Text(window.ownerName).font(.caption2))
            Text(window.title)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: Design.tileCorner)
                .fill(selected ? Color.accentColor.opacity(0.25) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Design.tileCorner)
                .stroke(selected ? Color.accentColor : Design.stroke, lineWidth: selected ? 2 : 1)
        )
        .shadow(color: selected ? Color.accentColor.opacity(0.3) : .clear, radius: selected ? 8 : 0)
    }
}
