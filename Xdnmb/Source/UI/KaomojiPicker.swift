//
// KaomojiPicker.swift
// Author: Maru
//

import SwiftUI

struct KaomojiPicker: View {
    let onSelect: (String) -> Void

    @State private var selectedCategoryID = KaomojiCatalog.categories[0].id

    private var selectedCategory: KaomojiCategory {
        KaomojiCatalog.categories.first { $0.id == selectedCategoryID }
        ?? KaomojiCatalog.categories[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("快捷颜文字", systemImage: "face.smiling")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Menu {
                    Picker("颜文字分类", selection: $selectedCategoryID) {
                        ForEach(KaomojiCatalog.categories) { category in
                            Label(category.name, systemImage: category.symbol)
                                .tag(category.id)
                        }
                    }
                } label: {
                    Label(selectedCategory.name, systemImage: "chevron.up.chevron.down")
                        .font(.caption)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(selectedCategory.values, id: \.self) { value in
                        Button(value) { onSelect(value) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityLabel("插入颜文字 \(value)")
                    }
                }
            }
        }
    }
}

private struct KaomojiCategory: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let values: [String]
}

private enum KaomojiCatalog {
    static let categories = [
        KaomojiCategory(
            id: "happy",
            name: "开心",
            symbol: "face.smiling",
            values: ["( ´ ▽ ` )ﾉ", "(｡･ω･｡)", "ヽ(✿ﾟ▽ﾟ)ノ", "(๑•̀ㅂ•́)و✧", "ヾ(≧▽≦*)o", "(≧∇≦)ﾉ"]
        ),
        KaomojiCategory(
            id: "sad",
            name: "难过",
            symbol: "cloud.rain",
            values: ["(；′⌒`)", "(╥﹏╥)", "(´；ω；`)", "(つД`)ノ", "(｡•́︿•̀｡)", "ಥ_ಥ"]
        ),
        KaomojiCategory(
            id: "surprise",
            name: "惊讶",
            symbol: "exclamationmark.bubble",
            values: ["Σ(っ °Д °;)っ", "(⊙o⊙)", "Σ(ﾟдﾟ;)", "(°ー°〃)", "(๑•̌.•̑๑)ˀ̣ˀ̣", "∑( 口 ||"]
        ),
        KaomojiCategory(
            id: "action",
            name: "动作",
            symbol: "figure.wave",
            values: ["ヾ(￣▽￣) Bye~Bye~", "(￣▽￣)／", "_(:з」∠)_", "(つ≧▽≦)つ", "┏(＾0＾)┛", "(ง •_•)ง"]
        ),
        KaomojiCategory(
            id: "island",
            name: "交流",
            symbol: "bubble.left.and.bubble.right",
            values: ["(=・ω・=)", "(｀・ω・´)", "( ´_ゝ`)", "(´・ω・`)", "(ﾟ∀ﾟ)", "(＾o＾)ﾉ"]
        )
    ]
}
