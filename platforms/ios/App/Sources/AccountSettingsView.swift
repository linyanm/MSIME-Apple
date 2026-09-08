import SwiftUI
import AuthenticationServices

struct AccountSettingsView: View {
  @State private var signedIn = false
  @State private var designs = CustomSkinLibrary.designs
  @State private var showPublish = false

  var body: some View {
    Form {
      AppleAccountSection(signedIn: $signedIn)

      Section("我的创作") {
        NavigationLink(destination: CustomSkinEditorView()) {
          HStack(spacing: 12) {
            accountIcon("paintbrush.pointed.fill", color: .purple)
            VStack(alignment: .leading, spacing: 4) {
              Text("我的设计").foregroundStyle(.primary)
              Text("保存在本机的 \(designs.count) 款皮肤").font(.caption).foregroundStyle(.secondary)
            }
          }.padding(.vertical, 4)
        }.accessibilityIdentifier("accountLocalDesigns")
        if signedIn {
          NavigationLink(destination: SkinCommunityView(onlyMine: true)) {
            HStack(spacing: 12) {
              accountIcon("square.stack.3d.up.fill", color: .orange)
              VStack(alignment: .leading, spacing: 4) {
                Text("已发布作品").foregroundStyle(.primary)
                Text("查看下载、评分和管理作品").font(.caption).foregroundStyle(.secondary)
              }
            }.padding(.vertical, 4)
          }.accessibilityIdentifier("accountPublishedSkins")
          Button { showPublish = true } label: {
            Label("发布新作品", systemImage: "square.and.arrow.up")
          }
        }
      }

      Section("发现与记录") {
        NavigationLink(destination: SkinCommunityView()) {
          HStack(spacing: 12) {
            accountIcon("person.3.fill", color: MetasequoiaTheme.forest)
            VStack(alignment: .leading, spacing: 4) {
              Text("皮肤社区").foregroundStyle(.primary)
              Text("发现设计，下载使用，为喜欢的作品评分").font(.caption).foregroundStyle(.secondary)
            }
          }.padding(.vertical, 4)
        }
        NavigationLink(destination: TypingStatisticsView()) {
          HStack(spacing: 12) {
            accountIcon("chart.bar.xaxis", color: .blue)
            VStack(alignment: .leading, spacing: 4) {
              Text("我的打字统计").foregroundStyle(.primary)
              Text("查看输入趋势和语言分布").font(.caption).foregroundStyle(.secondary)
            }
          }.padding(.vertical, 4)
        }
      }
      Section {
        Label("本地数据与云端作品", systemImage: "lock.shield")
          .font(.subheadline)
        Text("皮肤设计和打字统计保存在本机。只有你主动发布的作品会分享至社区；Apple 登录不会自动上传本地设计或输入记录。")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .navigationTitle("我的")
    .task { designs = CustomSkinLibrary.designs }
    .sheet(isPresented: $showPublish) { CommunityPublishView {} }
  }

  private func accountIcon(_ symbol: String, color: Color) -> some View {
    Image(systemName: symbol).font(.system(size: 19, weight: .semibold))
      .foregroundStyle(color).frame(width: 42, height: 42)
      .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
  }
}

struct AppleAccountSection: View {
  @Binding var signedIn: Bool
  @State private var user: CommunityUser?
  @State private var needsRecovery = false
  @State private var busy = false
  @State private var message: String?
  @State private var challenge: CommunityChallenge?
  @State private var confirmDeleteAccount = false
  private let api = SkinCommunityAPI.shared

  private var displayName: String {
    guard let name = user?.display_name, !name.isEmpty else { return "水杉用户" }
    return name
  }

  var body: some View {
    Section {
      HStack(spacing: 14) {
        Image(systemName: signedIn ? "person.crop.circle.fill" : "person.crop.circle")
          .font(.system(size: 48)).foregroundStyle(MetasequoiaTheme.forest)
        VStack(alignment: .leading, spacing: 5) {
          Text(signedIn ? displayName : "欢迎来到水杉")
            .font(.title3.bold())
          Text(signedIn ? "Apple 账号已登录" : "登录，分享你的键盘设计")
            .font(.subheadline).foregroundStyle(.secondary)
        }
      }.padding(.vertical, 10)
      if signedIn {
        Menu("账号") {
          Button("退出登录") { run { try await api.logout(); signedIn = false; await prepareLogin() } }
          Button("重新登录") { run { try await api.clearExpiredLogin(); signedIn = false; await prepareLogin() } }
          Button("注销账号", role: .destructive) { confirmDeleteAccount = true }
        }
      } else {
        if let challenge {
          SignInWithAppleButton(.signIn) { request in
            request.nonce = challenge.nonce
            request.state = challenge.challenge_id
          } onCompletion: { result in
            switch result {
            case .success(let authorization):
              guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                    credential.state == challenge.challenge_id,
                    let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else {
                message = "Apple 登录未返回有效凭据，请重试。"; Task { await prepareLogin() }; return
              }
              run {
                do { try await api.login(challenge: challenge.challenge_id, identityToken: token) }
                catch { await prepareLogin(); throw error }
                user = try await api.currentUser()
                signedIn = true
              }
            case .failure(let error):
              if (error as? ASAuthorizationError)?.code != .canceled { message = error.localizedDescription }
              Task { await prepareLogin() }
            }
          }.signInWithAppleButtonStyle(.black).frame(height: 44).disabled(busy)
        } else {
          Button("准备 Apple 登录") { Task { await prepareLogin() } }.disabled(busy)
        }
        Text("登录后可在皮肤社区发布、下载和评分。日常输入无需登录。").font(.caption).foregroundStyle(.secondary)
        if needsRecovery {
          Button("清除失效登录状态") { run { try await api.clearExpiredLogin(); signedIn = false; needsRecovery = false; await prepareLogin() } }
            .font(.caption)
        }
      }
    }
    .task {
      do { user = try await api.currentUser(); signedIn = user != nil } catch { needsRecovery = true; message = error.localizedDescription }
      if !signedIn { await prepareLogin() }
    }
    .alert("账号与登录", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
      Button("好", role: .cancel) {}
    } message: { Text(message ?? "") }
    .confirmationDialog("注销账号将删除已发布皮肤、评分及其他云端账号数据，无法撤销。", isPresented: $confirmDeleteAccount, titleVisibility: .visible) {
      Button("注销账号", role: .destructive) { run { try await api.logout(deleteAccount: true); signedIn = false; await prepareLogin() } }
    }
  }
  @MainActor private func prepareLogin() async {
    challenge = nil
    do { challenge = try await api.challenge() } catch { message = error.localizedDescription }
  }
  private func run(_ action: @escaping @MainActor () async throws -> Void) {
    guard !busy else { return }; busy = true
    Task { defer { busy = false }; do { try await action() } catch { message = error.localizedDescription } }
  }
}
