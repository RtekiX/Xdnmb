//
// PageJumpSheet.swift
// Author: Maru
//

import SwiftUI

struct PageJumpSheet: View {
    let currentPage: Int
    let maximumPage: Int
    let helpText: String
    let onJump: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pageText: String
    @FocusState private var pageFieldFocused: Bool

    init(
        currentPage: Int,
        maximumPage: Int,
        helpText: String = "输入目标页码后，将从该页重新开始浏览。",
        onJump: @escaping (Int) -> Void
    ) {
        self.currentPage = currentPage
        self.maximumPage = max(maximumPage, 1)
        self.helpText = helpText
        self.onJump = onJump
        _pageText = State(initialValue: String(currentPage))
    }

    private var targetPage: Int? {
        guard let page = Int(pageText),
              (1...maximumPage).contains(page) else { return nil }
        return page
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("目标页码") {
                    TextField("1–\(maximumPage)", text: $pageText)
                        .keyboardType(.numberPad)
                        .focused($pageFieldFocused)
                    LabeledContent("当前页", value: String(currentPage))
                    LabeledContent("可选范围", value: "1–\(maximumPage)")
                }
                Section {
                    Text(helpText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("跳转页码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("跳转") {
                        guard let targetPage else { return }
                        dismiss()
                        onJump(targetPage)
                    }
                    .fontWeight(.semibold)
                    .disabled(targetPage == nil || targetPage == currentPage)
                }
            }
            .onAppear { pageFieldFocused = true }
        }
        .presentationDetents([.medium])
    }
}
