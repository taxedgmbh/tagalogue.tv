//
//  SearchKeyboard.swift
//  tagalogue.tv
//
//  The grid keyboard screen 05 draws: a 660pt column, six square keys across
//  on a 14pt gap, with SPACE and CLEAR beneath.
//
//  This exists because tvOS's own `.searchable` does not present the layout the
//  design assumes. On tvOS 26 it renders a single-row horizontal keyboard strip
//  across the top of the screen with results in one full-width column below,
//  in system-styled rounded pills, localised to the device — and it stacks
//  under the app's own nav bar as a second header. Reaching screen 05 means
//  drawing the keyboard, the same trade already accepted for the player's
//  transport.
//

import SwiftUI

struct SearchKeyboard: View {
    @Binding var query: String

    /// Focus lives in the parent so the caller can hand first focus to "A".
    @FocusState.Binding var focusedKey: String?

    @State private var mode: Mode = .letters

    enum Mode { case letters, numbers }

    private static let letters: [String] =
        (65...90).map { String(UnicodeScalar($0)!) } + ["'", "-"]

    private static let numbers: [String] =
        ["1","2","3","4","5","6","7","8","9","0",".",",","'","-","&","/","(",")","+","?","!","·"]

    private var keys: [String] { mode == .letters ? Self.letters : Self.numbers }

    private let columns = Array(repeating: GridItem(.fixed(98), spacing: 14), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            field

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(keys, id: \.self) { key in
                    KeyButton(label: key, spoken: spoken(key)) { append(key) }
                        .focused($focusedKey, equals: key)
                }

                KeyButton(
                    label: mode == .letters ? "123" : "ABC",
                    spoken: mode == .letters ? "Numbers and punctuation" : "Letters",
                    size: 26
                ) {
                    mode = mode == .letters ? .numbers : .letters
                }
                .focused($focusedKey, equals: "mode")

                KeyButton(label: "⌫", spoken: "Delete", size: 26) {
                    if !query.isEmpty { query.removeLast() }
                }
                .focused($focusedKey, equals: "delete")
            }

            HStack(spacing: 14) {
                WideKeyButton(label: "Space") { query.append(" ") }
                    .focused($focusedKey, equals: "space")
                WideKeyButton(label: "Clear", width: 160) { query = "" }
                    .focused($focusedKey, equals: "clear")
                    .disabled(query.isEmpty)
                    .opacity(query.isEmpty ? 0.35 : 1)
            }
        }
        .frame(width: 660)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keyboard")
    }

    private var field: some View {
        HStack(spacing: 0) {
            // The caret leads an empty field and trails typed text, so the
            // placeholder never reads as something already entered.
            if !query.isEmpty {
                Text(query)
                    .archivo(.semibold, 31)
                    .foregroundStyle(Theme.paper)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Rectangle()
                .fill(Theme.accent)
                .frame(width: 3, height: 34)
                .padding(.leading, query.isEmpty ? 0 : 4)

            if query.isEmpty {
                Text("Search Tagalogue TV")
                    .archivo(.semibold, 31)
                    .foregroundStyle(Theme.paper(0.35))
                    .lineLimit(1)
                    .padding(.leading, 12)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .overlay(
            Rectangle().strokeBorder(Theme.paper(0.3), lineWidth: Theme.Metrics.rule)
        )
        .padding(.bottom, 20)
        .accessibilityElement()
        .accessibilityLabel("Search")
        .accessibilityValue(query.isEmpty ? "Empty" : query)
    }

    private func append(_ key: String) {
        query.append(key.lowercased())
    }

    private func spoken(_ key: String) -> String {
        switch key {
        case "'": "Apostrophe"
        case "-": "Hyphen"
        case ".": "Full stop"
        case ",": "Comma"
        case "·": "Middle dot"
        case "&": "Ampersand"
        case "/": "Slash"
        case "(": "Open bracket"
        case ")": "Close bracket"
        case "+": "Plus"
        case "?": "Question mark"
        case "!": "Exclamation mark"
        default: key
        }
    }
}

/// A square key. Same focus grammar as every other surface: square corners,
/// 2pt idle rule, 4pt accent rule, 4% lift.
private struct KeyButton: View {
    let label: String
    var spoken: String
    var size: CGFloat = 31
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .archivo(.bold, size)
                .frame(width: 98, height: 98)
        }
        .buttonStyle(KeyStyle())
        .accessibilityLabel(spoken)
    }
}

private struct WideKeyButton: View {
    let label: String
    var width: CGFloat? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .archivo(.bold, 25, tracking: 0.12)
                .textCase(.uppercase)
                .padding(.leading, 20)
                .frame(maxWidth: width == nil ? .infinity : width, alignment: .leading)
                .frame(height: 64)
        }
        .buttonStyle(KeyStyle())
    }
}

private struct KeyStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(focused ? Theme.paper : Theme.paper(0.75))
            .overlay(
                Rectangle().strokeBorder(
                    focused ? Theme.accent : Theme.paper(Theme.Metrics.idleRuleOpacity),
                    lineWidth: focused ? Theme.Metrics.focusBorder : Theme.Metrics.rule
                )
            )
            .scaleEffect(focused ? Theme.Metrics.focusScale : 1)
            .animation(.easeOut(duration: 0.12), value: focused)
    }
}
