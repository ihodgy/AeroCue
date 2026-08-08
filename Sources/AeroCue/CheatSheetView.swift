import SwiftUI

struct ModeSection: Identifiable {
    let id: String
    var name: String { id }
    let categories: [CategorySection]
    /// The shortcut that switches into this mode, found in whichever other mode
    /// binds `mode <name>`. Nil for the mode you're normally in.
    var enterCombo: KeyCombo? = nil
    /// True when every binding here drops back to main mode afterwards.
    var returnsToMain: Bool = false
}

struct CategorySection: Identifiable {
    let id: String
    var name: String { id }
    let bindings: [KeyBinding]
}

enum CheatSheetBuilder {
    static func build(from bindings: [KeyBinding]) -> [ModeSection] {
        let modeOrder: (String) -> Int = { $0 == "main" ? 0 : 1 }
        let modes = Dictionary(grouping: bindings, by: { $0.mode })
        return modes.keys.sorted { a, b in
            let oa = modeOrder(a), ob = modeOrder(b)
            return oa != ob ? oa < ob : a < b
        }.map { mode in
            let modeBindings = modes[mode] ?? []
            let byCategory = Dictionary(grouping: modeBindings, by: { $0.category })
            let categories = byCategory.keys.sorted().map { cat in
                CategorySection(id: cat, bindings: (byCategory[cat] ?? []).sorted { $0.rawKey < $1.rawKey })
            }

            // "How do I get into this mode?" lives in a *different* mode's
            // bindings, so look for whoever runs `mode <name>`. Main is the
            // resting state -- the keys that return to it aren't a way "in".
            let enter = mode == "main" ? nil : bindings.first { binding in
                binding.mode != mode && binding.commands.contains("mode \(mode)")
            }
            let returnsToMain = mode != "main"
                && !modeBindings.isEmpty
                && modeBindings.allSatisfy { $0.commands.contains("mode main") }

            return ModeSection(
                id: mode,
                categories: categories,
                enterCombo: enter?.combo,
                returnsToMain: returnsToMain
            )
        }
    }
}

struct CheatSheetView: View {
    let modes: [ModeSection]
    let configPath: String?
    var size: CGSize = CGSize(width: 900, height: 620)
    var onDismiss: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Color.white.opacity(0.1))
            if modes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        ForEach(modes) { mode in
                            modeBlock(mode)
                        }
                    }
                    .padding(28)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        // Global mouse monitors never see clicks that land on our own app's
        // windows, so clicking the sheet itself needs its own dismiss handler.
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("AeroSpace Shortcuts")
                    .font(.system(size: 30, weight: .semibold))
                Text(configPath ?? "No aerospace.toml found")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Release ⌥ to dismiss")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("Couldn't find any [mode.*.binding] entries.")
                .font(.system(size: 16, weight: .medium))
            Text("Checked ~/.config/aerospace/aerospace.toml and ~/.aerospace.toml")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func modeBlock(_ mode: ModeSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if mode.name != "main" || modes.count > 1 {
                HStack(spacing: 10) {
                    Text(mode.name == "main" ? "MAIN MODE" : "\(mode.name.uppercased()) MODE")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.secondary)

                    if let combo = mode.enterCombo {
                        HStack(spacing: 6) {
                            Text("enter with")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                            ComboView(combo: combo, fixedWidth: false)
                            if mode.returnsToMain {
                                Text("— then one key, and it drops back to main")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.top, mode.id == modes.first?.id ? 0 : 6)
            }
            // A grid would make every card in a row as tall as the tallest one,
            // stranding a lot of empty space. Packing balanced columns instead
            // keeps the whole sheet on one screen without scrolling.
            HStack(alignment: .top, spacing: 18) {
                ForEach(Array(balancedColumns(mode.categories).enumerated()), id: \.offset) { _, column in
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(column) { category in
                            categoryCard(category)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
    }

    private var columnCount: Int {
        max(1, min(8, Int((size.width - 56) / 470)))
    }

    /// Greedy longest-first bin packing: repeatedly drop the next-biggest
    /// category into whichever column is currently shortest.
    private func balancedColumns(_ categories: [CategorySection]) -> [[CategorySection]] {
        let count = min(columnCount, max(1, categories.count))
        var columns = Array(repeating: [CategorySection](), count: count)
        var weights = Array(repeating: 0, count: count)

        for category in categories.sorted(by: { $0.bindings.count > $1.bindings.count }) {
            let target = weights.enumerated().min { a, b in
                a.element != b.element ? a.element < b.element : a.offset < b.offset
            }!.offset
            columns[target].append(category)
            weights[target] += category.bindings.count + 2 // header + card padding
        }
        // Packing order is by size; restore alphabetical order within each column.
        return columns.map { $0.sorted { $0.name < $1.name } }
    }

    @ViewBuilder
    private func categoryCard(_ category: CategorySection) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(category.name)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.primary.opacity(0.85))
                .padding(.bottom, 3)
            ForEach(category.bindings) { binding in
                HStack(alignment: .top, spacing: 10) {
                    ComboView(combo: binding.combo)
                    Text(binding.actionDescription)
                        .font(.system(size: 19))
                        .foregroundStyle(.primary.opacity(0.9))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.05)))
    }
}

struct ComboView: View {
    let combo: KeyCombo
    /// Card rows share a common gutter so descriptions line up; inline uses
    /// (like the mode header) should hug their content instead.
    var fixedWidth: Bool = true

    var body: some View {
        HStack(spacing: 3) {
            ForEach(combo.modifierSymbols, id: \.self) { sym in
                KeyCap(text: sym)
            }
            KeyCap(text: combo.keySymbol)
        }
        .frame(minWidth: fixedWidth ? 128 : nil, alignment: .leading)
    }
}

struct KeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.white.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5))
    }
}
