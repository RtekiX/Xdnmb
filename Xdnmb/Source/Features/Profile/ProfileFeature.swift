//
// ProfileFeature.swift
// Author: Maru
//

import SafariServices
import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var identity: IdentityStore
    @State private var showingIdentityEditor = false
    @State private var showingClearConfirmation = false
    @State private var showingAccountCenter = false
    @State private var recentThreadID: Int?
    @State private var accountMessage: String?
    @State private var isFindingLastPost = false

    private let accountCenterURL = URL(string: "https://www.nmbxd.com/Member/User/Cookie/index.html")

    var body: some View {
        List {
            identityStatusSection
            identitySection
            accountSection
            privacySection
            connectionSection
            Section {
                Text("Xdnmb 是非官方客户端。请遵守站点规则，并妥善保管账号、饼干和 Feed ID。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("我的")
        .sheet(isPresented: $showingIdentityEditor) {
            IdentityEditor(identity: identity)
        }
        .sheet(isPresented: $showingAccountCenter) {
            if let accountCenterURL {
                SafariView(url: accountCenterURL).ignoresSafeArea()
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { recentThreadID != nil },
            set: { if !$0 { recentThreadID = nil } }
        )) {
            if let id = recentThreadID { ThreadDetailScreen(threadID: id) }
        }
        .alert("提示", isPresented: Binding(
            get: { accountMessage != nil },
            set: { if !$0 { accountMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(accountMessage ?? "")
        }
        .confirmationDialog(
            "移除本地饼干？",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("移除", role: .destructive) { identity.clearIdentity() }
        } message: {
            Text("移除后将无法发帖与管理订阅，但不会删除服务器上的身份。")
        }
    }

    private var identityStatusSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: identity.hasIdentity
                      ? "checkmark.shield.fill"
                      : "person.crop.circle.badge.questionmark")
                    .font(.system(size: 34))
                    .foregroundStyle(identity.hasIdentity ? AppTheme.accent : .secondary)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.accent.opacity(0.1), in: .rect(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(identity.hasIdentity ? "匿名身份已就绪" : "尚未导入饼干")
                        .font(.headline)
                    Text(identity.hasIdentity
                         ? "可以发帖、回复和管理订阅"
                         : "浏览无需登录，互动需要饼干")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var identitySection: some View {
        Section("身份与订阅") {
            Button { showingIdentityEditor = true } label: {
                Label(identity.hasIdentity ? "编辑本地身份" : "导入饼干", systemImage: "key")
            }
            LabeledContent("Feed ID") {
                Text(identity.feedID)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            if identity.hasIdentity {
                Button { Task { await findLastPost() } } label: {
                    Label(
                        isFindingLastPost ? "正在查找…" : "查看我最近发送的帖子",
                        systemImage: isFindingLastPost ? "clock.arrow.circlepath" : "paperplane"
                    )
                }
                .disabled(isFindingLastPost)
                Button("移除本地饼干", role: .destructive) {
                    showingClearConfirmation = true
                }
            }
        }
    }

    private var accountSection: some View {
        Section("实名账号后台") {
            Button { showingAccountCenter = true } label: {
                Label("打开账号与饼干中心", systemImage: "person.badge.key")
            }
            .disabled(accountCenterURL == nil)
            Text("登录、注册、找回密码和申请新饼干由站点安全页面完成；回到 App 后可导入导出的 userhash。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var privacySection: some View {
        Section("隐私说明") {
            Label("发帖时仅发送 userhash，前台保持匿名", systemImage: "eye.slash")
            Label("饼干保存在设备钥匙串，不会同步", systemImage: "lock.iphone")
            Label("Feed ID 用于找回订阅，可单独备份", systemImage: "bookmark")
        }
    }

    private var connectionSection: some View {
        Section("连接") {
            Button { Task { await app.bootstrap() } } label: {
                Label("重新发现服务器节点", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(app.isBootstrapping)
            LabeledContent("状态", value: app.isBootstrapping
                           ? "正在连接"
                           : (app.isConnected ? "已连接" : "连接异常"))
        }
    }

    private func findLastPost() async {
        guard let hash = identity.userHash.nilIfBlank, !isFindingLastPost else { return }
        isFindingLastPost = true
        defer { isFindingLastPost = false }
        do {
            recentThreadID = try await APIService.shared.lastPost(userHash: hash).threadID
        } catch is CancellationError {
            return
        } catch {
            accountMessage = error.localizedDescription
        }
    }
}

private struct IdentityEditor: View {
    @ObservedObject var identity: IdentityStore
    @Environment(\.dismiss) private var dismiss
    @State private var userHash: String
    @State private var feedID: String
    @State private var errorMessage: String?

    init(identity: IdentityStore) {
        self.identity = identity
        _userHash = State(initialValue: identity.userHash)
        _feedID = State(initialValue: identity.feedID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("userhash 饼干") {
                    SecureField("粘贴 userhash", text: $userHash)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("可以粘贴纯 hash，或完整的 userhash=…；保存时会自动清理前缀。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Feed ID") {
                    TextField("UUID", text: $feedID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("生成新的 Feed ID") {
                        feedID = UUID().uuidString.lowercased()
                    }
                }
            }
            .navigationTitle("本地身份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(
                            userHash.nilIfBlank == nil ||
                            UUID(uuidString: feedID.trimmingCharacters(in: .whitespacesAndNewlines)) == nil
                        )
                }
            }
            .alert("无法保存", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        do {
            try identity.save(userHash: userHash, feedID: feedID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ThreadJumpSheet: View {
    let onOpen: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value = ""

    private var threadID: Int? {
        let number = Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        return (number ?? 0) > 0 ? number : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("串号") {
                    TextField("例如 69047539", text: $value)
                        .keyboardType(.numberPad)
                }
                Section {
                    Text("输入主串号后可直接打开，不必先找到所在版块。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("串号直达")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("打开") {
                        guard let threadID else { return }
                        dismiss()
                        onOpen(threadID)
                    }
                    .disabled(threadID == nil)
                }
            }
        }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
