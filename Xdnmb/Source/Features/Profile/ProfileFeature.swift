//
// ProfileFeature.swift
// Author: Maru
//

import SafariServices
import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var identity: IdentityStore
    @Environment(\.appRuntimeMode) private var runtimeMode
    @State private var showingIdentityEditor = false
    @State private var showingClearConfirmation = false
    @State private var showingAccountCenter = false
    @State private var showingPrivacy = false
    @State private var recentThreadID: Int?
    @State private var accountMessage: String?
    @State private var isFindingLastPost = false

    private let accountCenterURL = URL(string: "https://www.nmbxd.com/Member/User/Cookie/index.html")

    var body: some View {
        List {
            identityStatusSection
            identitySection
            accountSection
            connectionSection
            Section {
                Text("Xdnmb 是非官方客户端。请遵守站点规则，并妥善保管账号、饼干和 Feed ID。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("我的")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingPrivacy = true } label: {
                    Label("隐私说明", systemImage: "hand.raised.fill")
                }
                .accessibilityHint("查看完整隐私声明")
            }
        }
        .sheet(isPresented: $showingIdentityEditor) {
            IdentityEditor(identity: identity)
        }
        .sheet(isPresented: $showingAccountCenter) {
            if let accountCenterURL {
                SafariView(url: accountCenterURL).ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyStatementSheet()
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
            Button {
                if runtimeMode.isPreview {
                    accountMessage = "Preview 模式不会打开外部账号页面。"
                } else {
                    showingAccountCenter = true
                }
            } label: {
                Label("打开账号与饼干中心", systemImage: "person.badge.key")
            }
            .disabled(accountCenterURL == nil)
            Text("登录、注册、找回密码和申请新饼干由站点安全页面完成；回到 App 后可导入导出的 userhash。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var connectionSection: some View {
        Section("连接") {
            Button { Task { await reconnect() } } label: {
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
        if runtimeMode.isPreview {
            recentThreadID = PreviewFixtures.threads[0].id
            return
        }
        do {
            recentThreadID = try await APIService.shared.lastPost(userHash: hash).threadID
        } catch is CancellationError {
            return
        } catch {
            accountMessage = error.localizedDescription
        }
    }

    private func reconnect() async {
        guard !runtimeMode.isPreview else {
            accountMessage = "Preview 正在使用本地示例数据。"
            return
        }
        await app.bootstrap()
    }
}

private struct IdentityEditor: View {
    @ObservedObject var identity: IdentityStore
    @Environment(\.dismiss) private var dismiss
    @State private var userHash: String
    @State private var feedID: String
    @State private var errorMessage: String?
    @State private var showingScanner = false

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
                    Button { openScanner() } label: {
                        Label("扫描二维码导入", systemImage: "qrcode.viewfinder")
                    }
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
            .sheet(isPresented: $showingScanner) {
                NavigationStack {
                    QRCodeScannerView { value in
                        importScannedValue(value)
                    }
                    .ignoresSafeArea()
                    .navigationTitle("扫描饼干二维码")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") { showingScanner = false }
                        }
                    }
                    .overlay(alignment: .bottom) {
                        Text("将包含 userhash 的二维码放入取景框")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(.black.opacity(0.65), in: .capsule)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    private func openScanner() {
        guard QRCodeScannerView.isAvailable else {
            errorMessage = "当前设备无法使用二维码扫描，请手动粘贴 userhash。"
            return
        }
        showingScanner = true
    }

    private func importScannedValue(_ value: String) {
        do {
            userHash = try IdentityStore.normalizeUserHash(value)
            showingScanner = false
        } catch {
            errorMessage = "二维码中没有有效的 userhash。"
            showingScanner = false
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

private struct PrivacyStatementSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let statements = [
        ("eye.slash", "前台匿名", "浏览无需登录；发帖和回复时只向站点发送 userhash，帖子前台不会展示实名账号。"),
        ("lock.iphone", "本地凭据", "userhash 保存在本机钥匙串，不通过 iCloud 同步；移除后 App 无法恢复。"),
        ("bookmark", "订阅标识", "Feed ID 保存在本机偏好设置，并用于读取和管理站点订阅。"),
        ("camera.viewfinder", "相机", "相机仅在扫描饼干二维码时启用，画面不会被保存或上传。"),
        ("photo", "照片", "只有在你选择上传或保存图片时，App 才会访问对应图片数据。"),
        ("network", "网络请求", "论坛内容、发帖、回复和订阅操作会与 X 岛 API 及图片服务器通信。")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("隐私与匿名说明", systemImage: "hand.raised.fill")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.accent)
                    Text("当前 API 未提供官方隐私声明接口，以下为 Xdnmb 客户端依据实际数据行为整理的本地说明。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(Array(statements.enumerated()), id: \.offset) { _, statement in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: statement.0)
                                .font(.title3)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(statement.1).font(.headline)
                                Text(statement.2)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("隐私说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
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
