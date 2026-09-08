import AuthenticationServices
import SwiftUI

@MainActor
final class AccountSettingsModel: ObservableObject {
  @Published var user: BackendAccountClient.User?
  @Published var providers: [String: Bool] = [:]
  @Published var challenge: BackendAccountClient.Challenge?
  @Published var busy = false
  @Published var message: String?
  let client = BackendAccountClient()
  let session = BackendAccountSession()

  func load() async {
    await perform {
      self.providers = try await self.client.providers()
      self.user = try await self.session.user()
      if self.user != nil {
        do {
          let token = try await self.session.accessToken()
          self.user = try await self.client.profile(token: token).user
        } catch let failure as BackendAccountClient.Failure where failure.status == 401 {
          try await self.session.forget(); self.user = nil
        }
      }
      if self.user == nil && self.providers["apple"] == true {
        self.challenge = try await self.client.challenge(provider: "apple")
      }
    }
  }
  func signIn(_ authorization: ASAuthorization, challenge: BackendAccountClient.Challenge) async {
    await perform {
      guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            credential.state == challenge.challenge_id,
            let bytes = credential.identityToken, let token = String(data: bytes, encoding: .utf8)
      else { throw BackendAccountClient.Failure(status: 401) }
      try await self.session.signIn(challenge: challenge.challenge_id, credential: token)
      self.user = try await self.session.user(); self.challenge = nil
    }
  }
  func rename(_ name: String) async {
    await perform {
      let token = try await self.session.accessToken()
      try await self.client.rename(name, token: token)
      self.user = try await self.client.profile(token: token).user
    }
  }
  func logout(all: Bool = false) async {
    await perform {
      defer { self.user = nil; self.challenge = nil }
      try await self.session.logout(all: all)
    }
    let logoutMessage = message
    await load()
    if let logoutMessage { message = logoutMessage }
  }
  func deleteAccount() async {
    await perform {
      let token = try await self.session.accessToken()
      try await self.client.deleteAccount(token: token)
      try await self.session.forget(); self.user = nil; self.challenge = nil
    }
    if user == nil { await load() }
  }
  private func perform(_ operation: () async throws -> Void) async {
    guard !busy else { return }
    busy = true; message = nil
    defer { busy = false }
    do { try await operation() }
    catch is CancellationError { }
    catch let error as BackendAccountClient.Failure { message = error.localizedDescription }
    catch { message = "连接未完成，请检查网络后重试。" }
  }
}

struct AccountSettingsView: View {
  @StateObject private var model = AccountSettingsModel()
  @State private var appleChallenge: BackendAccountClient.Challenge?
  @State private var name = ""
  @State private var confirmDelete = false
  @State private var confirmLogoutAll = false

  var body: some View {
    Form {
      if let user = model.user {
        Section("我的账号") {
          Text(user.display_name.isEmpty ? "水杉用户" : user.display_name)
          TextField("昵称", text: $name)
            .onAppear { name = user.display_name }
            .accessibilityIdentifier("accountDisplayName")
          Button("保存昵称") { Task { await model.rename(name) } }
            .disabled(name.count > 64 || name == user.display_name)
          Button("退出登录") { Task { await model.logout() } }
          Button("退出所有设备") { confirmLogoutAll = true }
        }
        Section {
          Button("注销账号", role: .destructive) { confirmDelete = true }
        } footer: {
          Text("注销会删除云端账号及关联的词库、设置和剪贴板数据，需要最近十分钟内登录。")
        }
      } else {
        Section {
          if model.providers["apple"] == true {
            SignInWithAppleButton(.signIn) { request in
              appleChallenge = model.challenge
              request.nonce = model.challenge?.nonce
              request.state = model.challenge?.challenge_id
            } onCompletion: { result in
              guard let challenge = appleChallenge else { return }
              appleChallenge = nil
              switch result {
              case .success(let authorization): Task { await model.signIn(authorization, challenge: challenge) }
              case .failure(let error):
                if (error as? ASAuthorizationError)?.code != .canceled {
                  model.message = "Apple 登录未完成，请重试。"
                }
                Task { await model.load() }
              }
            }
            .frame(height: 46)
            .disabled(model.challenge?.nonce == nil)
            .accessibilityIdentifier("backendAppleSignIn")
          }
          Button("刷新登录方式") { Task { await model.load() } }
        } header: {
          Text("登录水杉账号")
        } footer: {
          Text("登录本身不会上传输入内容、个人词库或系统剪贴板。")
        }
      }
      if model.busy { ProgressView("正在处理…") }
      if let message = model.message { Text(message).foregroundStyle(.secondary) }
    }
    .disabled(model.busy)
    .navigationTitle("账号")
    .task { await model.load() }
    .alert("注销水杉账号？", isPresented: $confirmDelete) {
      Button("取消", role: .cancel) { }
      Button("永久注销", role: .destructive) { Task { await model.deleteAccount() } }
    } message: { Text("此操作无法撤销。云端账号及关联数据将被删除。") }
    .alert("退出所有设备？", isPresented: $confirmLogoutAll) {
      Button("取消", role: .cancel) { }
      Button("退出所有设备", role: .destructive) { Task { await model.logout(all: true) } }
    } message: { Text("所有设备都需要重新登录。") }
  }
}
