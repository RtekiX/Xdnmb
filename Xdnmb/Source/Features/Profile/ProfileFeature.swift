//
// ProfileFeature.swift
// Author: Maru
//

import AVFoundation
import PhotosUI
import SafariServices
import SwiftUI
import UIKit
import Vision

struct ProfileScreen: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var identity: IdentityStore
    @Environment(\.appRuntimeMode) private var runtimeMode
    @State private var showingCookieManagement = false
    @State private var showingAccountCenter = false
    @State private var showingPrivacy = false
    @State private var recentThreadID: Int?
    @State private var accountMessage: String?
    @State private var isFindingLastPost = false

    private let accountCenterURL = URL(string: "https://www.nmbxd.com/Member/User/Cookie/index.html")
    private let policiesThreadID = 11_689_471

    var body: some View {
        Group {
            List {
                identityStatusSection
                identitySection
                accountSection
                connectionSection
                policiesSection
                Section {
                    Text("Xdnmb 是非官方客户端。请遵守站点规则，并妥善保管账号、饼干和 Feed ID。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.large)
        .xdnmbSoftScrollEdgeEffect()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingPrivacy = true } label: {
                    Label("隐私说明", systemImage: "hand.raised.fill")
                }
                .accessibilityHint("查看完整隐私声明")
            }
        }
        .sheet(isPresented: $showingCookieManagement) {
            CookieManagementScreen(identity: identity)
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
                    Text(identity.hasIdentity ? "已保存 \(identity.cookies.count) 个饼干" : "尚未导入饼干")
                        .font(.headline)
                    Text(identity.hasIdentity ? primaryCookieSummary : "请通过相册或相机二维码导入")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var identitySection: some View {
        Section("身份与订阅") {
            Button { showingCookieManagement = true } label: {
                Label(
                    identity.hasIdentity ? "管理饼干（\(identity.cookies.count)/5）" : "二维码导入饼干",
                    systemImage: "qrcode"
                )
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
            Text("登录、注册、找回密码和申请新饼干由站点安全页面完成；回到 App 后可扫描导出的饼干二维码。")
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

    private var policiesSection: some View {
        Section("关于") {
            NavigationLink {
                ThreadDetailScreen(threadID: policiesThreadID)
            } label: {
                Label("服务协议与隐私政策", systemImage: "doc.text")
            }
        }
    }

    private func findLastPost() async {
        guard let hash = identity.postingUserHash, !isFindingLastPost else { return }
        isFindingLastPost = true
        defer { isFindingLastPost = false }
        if runtimeMode.isPreview {
            recentThreadID = PreviewFixtures.threads[0].id
            return
        }
        do {
            recentThreadID = try await app.lastPost(userHash: hash).threadID
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
        await app.bootstrap(userHash: identity.browsingUserHash)
    }

    private var primaryCookieSummary: String {
        let browsingName = identity.browsingCookie?.name ?? "未设置"
        let postingName = identity.postingCookie?.name ?? "未设置"
        return "浏览：\(browsingName) · 发帖：\(postingName)"
    }
}

private struct CookieManagementScreen: View {
    @ObservedObject var identity: IdentityStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var feedID: String
    @State private var errorMessage: String?
    @State private var showingScanner = false
    @State private var showingCameraPermissionAlert = false
    @State private var selectedQRCodePhoto: PhotosPickerItem?
    @State private var isReadingQRCode = false
    @State private var cookiePendingDeletion: IdentityCookie?

    init(identity: IdentityStore) {
        self.identity = identity
        _feedID = State(initialValue: identity.feedID)
    }

    var body: some View {
        NavigationStack {
            Form {
                cookieListSection
                if identity.hasIdentity {
                    primaryCookieSection
                }
                Section("二维码导入") {
                    PhotosPicker(selection: $selectedQRCodePhoto, matching: .images) {
                        Label(
                            isReadingQRCode ? "正在识别二维码…" : "从相册选择二维码",
                            systemImage: isReadingQRCode ? "hourglass" : "photo.badge.plus"
                        )
                    }
                    .disabled(!identity.canImportCookie || isReadingQRCode)

                    Button { requestCameraAccess() } label: {
                        Label("使用相机扫描二维码", systemImage: "qrcode.viewfinder")
                    }
                    .disabled(!identity.canImportCookie || isReadingQRCode)

                    Text(importHelpText)
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
                    Button("保存 Feed ID") { saveFeedID() }
                        .disabled(
                            UUID(uuidString: feedID.trimmingCharacters(in: .whitespacesAndNewlines)) == nil ||
                            feedID.caseInsensitiveCompare(identity.feedID) == .orderedSame
                        )
                }
            }
            .navigationTitle("饼干管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task(id: selectedQRCodePhoto) { await importSelectedPhoto() }
            .alert("操作失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("无法使用相机", isPresented: $showingCameraPermissionAlert) {
                Button("打开设置") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        openURL(settingsURL)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("请在系统设置中允许 Xdnmb 使用相机。相机只在扫描饼干二维码时开启。")
            }
            .confirmationDialog(
                "移除这个饼干？",
                isPresented: Binding(
                    get: { cookiePendingDeletion != nil },
                    set: { if !$0 { cookiePendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let cookie = cookiePendingDeletion {
                    Button("移除 \(cookie.name)", role: .destructive) {
                        removeCookie(cookie)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("只会从本机钥匙串移除，不会删除服务器上的身份。")
            }
            .fullScreenCover(isPresented: $showingScanner) {
                NavigationStack {
                    QRCodeScannerView { value in
                        importQRCode(value)
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

    private var cookieListSection: some View {
        Section("已保存的饼干（\(identity.cookies.count)/\(IdentityStore.maximumCookieCount)）") {
            if identity.cookies.isEmpty {
                ContentUnavailableView(
                    "还没有饼干",
                    systemImage: "key.slash",
                    description: Text("请从相册选择二维码，或使用相机扫描。")
                )
            } else {
                ForEach(identity.cookies) { cookie in
                    HStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.accent.opacity(0.1), in: .circle)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(cookie.name).font(.headline)
                            Text(cookie.maskedUserHash)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            if identity.browsingCookieID == cookie.id {
                                Text("浏览主饼干")
                                    .foregroundStyle(AppTheme.accent)
                            }
                            if identity.postingCookieID == cookie.id {
                                Text("发帖主饼干")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)
                    }
                    .swipeActions {
                        Button("移除", role: .destructive) {
                            cookiePendingDeletion = cookie
                        }
                    }
                }
            }
        }
    }

    private var primaryCookieSection: some View {
        Section("主饼干") {
            Picker("浏览鉴权", selection: browsingCookieSelection) {
                ForEach(identity.cookies) { cookie in
                    Text(cookie.name).tag(Optional(cookie.id))
                }
            }
            Picker("发帖与回复", selection: postingCookieSelection) {
                ForEach(identity.cookies) { cookie in
                    Text(cookie.name).tag(Optional(cookie.id))
                }
            }
            Text("浏览主饼干用于读取时间线、版块、帖子和订阅；发帖主饼干是发帖与回复页面的默认选择。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var browsingCookieSelection: Binding<UUID?> {
        Binding(
            get: { identity.browsingCookieID },
            set: { id in
                guard let id else { return }
                do {
                    try identity.setBrowsingCookie(id: id)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        )
    }

    private var postingCookieSelection: Binding<UUID?> {
        Binding(
            get: { identity.postingCookieID },
            set: { id in
                guard let id else { return }
                do {
                    try identity.setPostingCookie(id: id)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        )
    }

    private var importHelpText: String {
        if identity.canImportCookie {
            return "仅支持二维码导入。相册使用系统照片选择器，不会授予 App 整个相册的访问权限；相机权限只会在点击扫描时申请。"
        }
        return "已达到 5 个饼干上限，请先移除一个再导入。"
    }

    private func requestCameraAccess() {
        guard identity.canImportCookie else {
            errorMessage = IdentityStoreError.cookieLimitReached.localizedDescription
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentScanner()
        case .notDetermined:
            Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    presentScanner()
                } else {
                    showingCameraPermissionAlert = true
                }
            }
        case .denied, .restricted:
            showingCameraPermissionAlert = true
        @unknown default:
            showingCameraPermissionAlert = true
        }
    }

    private func presentScanner() {
        guard QRCodeScannerView.isAvailable else {
            errorMessage = "当前设备无法使用相机扫描，请改从相册选择二维码。"
            return
        }
        showingScanner = true
    }

    private func importSelectedPhoto() async {
        guard let selectedQRCodePhoto else { return }
        isReadingQRCode = true
        defer {
            isReadingQRCode = false
            self.selectedQRCodePhoto = nil
        }

        do {
            guard identity.canImportCookie else { throw IdentityStoreError.cookieLimitReached }
            guard let data = try await selectedQRCodePhoto.loadTransferable(type: Data.self) else {
                throw QRCodeImportError.unreadableImage
            }
            let value = try await QRCodeImageReader.payload(from: data)
            _ = try identity.importCookie(fromQRCode: value)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = cookieImportErrorMessage(error)
        }
    }

    private func importQRCode(_ value: String) {
        do {
            _ = try identity.importCookie(fromQRCode: value)
            showingScanner = false
        } catch {
            showingScanner = false
            errorMessage = cookieImportErrorMessage(error)
        }
    }

    private func removeCookie(_ cookie: IdentityCookie) {
        do {
            try identity.removeCookie(id: cookie.id)
            cookiePendingDeletion = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveFeedID() {
        do {
            try identity.saveFeedID(feedID)
            feedID = identity.feedID
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cookieImportErrorMessage(_ error: Error) -> String {
        if let identityError = error as? IdentityStoreError,
           case .invalidUserHash = identityError {
            return "二维码中没有有效的 userhash"
        }
        return error.localizedDescription
    }
}

private enum QRCodeImportError: LocalizedError {
    case unreadableImage
    case missingQRCode

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "无法读取所选图片，请重新选择"
        case .missingQRCode:
            return "所选图片中没有可识别的二维码"
        }
    }
}

private enum QRCodeImageReader {
    static func payload(from data: Data) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]
            let handler = VNImageRequestHandler(data: data)
            try handler.perform([request])
            guard let value = request.results?.lazy.compactMap(\.payloadStringValue).first?.nilIfBlank else {
                throw QRCodeImportError.missingQRCode
            }
            return value
        }.value
    }
}

private struct PrivacyStatementSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let statements = [
        ("eye.slash", "前台匿名", "可选择浏览主饼干用于鉴权；发帖和回复只发送当次选定的 userhash，帖子前台不会展示实名账号。"),
        ("lock.iphone", "本地凭据", "最多 5 个 userhash 及主饼干设置保存在本机钥匙串，不通过 iCloud 同步；移除后 App 无法恢复。"),
        ("bookmark", "订阅标识", "Feed ID 保存在本机偏好设置，并用于读取和管理站点订阅。"),
        ("camera.viewfinder", "相机", "相机权限只在你点击扫描饼干二维码时申请；画面不会被保存或上传。"),
        ("photo", "照片", "饼干导入使用系统照片选择器，只读取你选中的二维码图片；发帖和保存图片同样只处理你主动选择的内容。"),
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
