//
// StateViews.swift
// Author: Maru
//

import SwiftUI

struct LoadingView: View {
    let title: String

    var body: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            Text(title).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct RetryView: View {
    let title: String
    let message: String
    let action: () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("重试") { Task { await action() } }
                .buttonStyle(.borderedProminent)
        }
    }
}

struct SendingOverlay: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在发送…").font(.subheadline)
        }
        .padding(24)
        .background(.regularMaterial, in: .rect(cornerRadius: 18))
        .shadow(radius: 12)
        .accessibilityElement(children: .combine)
    }
}

struct ContextBanner: View {
    let icon: String
    let text: String

    var body: some View {
        Label {
            Text(text).font(.subheadline).foregroundStyle(.secondary)
        } icon: {
            Image(systemName: icon).foregroundStyle(AppTheme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card, in: .rect(cornerRadius: 14))
    }
}

struct PageControl: View {
    let page: Int
    let maxPage: Int
    let isLoading: Bool
    let onPrevious: () async -> Void
    let onNext: () async -> Void

    var body: some View {
        HStack {
            Button {
                Task { await onPrevious() }
            } label: {
                Label("上一页", systemImage: "chevron.left")
            }
            .disabled(page <= 1 || isLoading)

            Spacer()
            if isLoading {
                ProgressView().controlSize(.small)
            } else {
                Text("\(page) / \(maxPage)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Button {
                Task { await onNext() }
            } label: {
                Label("下一页", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(page >= maxPage || isLoading)
        }
        .buttonStyle(.bordered)
        .padding(.vertical, 8)
    }
}
