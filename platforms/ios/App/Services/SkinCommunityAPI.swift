import Foundation
import Security

struct CommunitySkin: Codable, Identifiable, Sendable {
  let id: String
  let name: String
  let description: String
  let author: String
  let design: CustomKeyboardSkin
  let downloads: Int
  let rating_count: Int
  let rating_average: Double
  let owned: Bool
  let my_rating: Int
}
struct CommunityPage: Decodable, Sendable { let skins: [CommunitySkin]; let has_more: Bool }
struct CommunityChallenge: Decodable, Sendable { let challenge_id: String; let nonce: String }
struct CommunityUser: Codable, Sendable { let id: String; let display_name: String }
struct CommunityTokens: Codable, Sendable {
  let access_token: String
  let refresh_token: String
  let user: CommunityUser
}
struct CommunityFailure: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}

enum CommunityCredentials {
  private static var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "app.msime.ios.community", kSecAttrAccount as String: "api.msime.app"] }
  static func load() throws -> CommunityTokens? {
    var query = query
    query[kSecReturnData as String] = true
    var value: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &value)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = value as? Data else { throw CommunityFailure(message: "请解锁设备后读取登录状态。") }
    return try JSONDecoder().decode(CommunityTokens.self, from: data)
  }
  static func save(_ tokens: CommunityTokens?) throws {
    guard let tokens else {
      let status = SecItemDelete(query as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else { throw CommunityFailure(message: "无法清除登录状态。") }
      return
    }
    let values: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(tokens)]
    var status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
    if status == errSecItemNotFound {
      var item = query.merging(values) { _, new in new }
      item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      status = SecItemAdd(item as CFDictionary, nil)
    }
    guard status == errSecSuccess else { throw CommunityFailure(message: "无法安全保存登录状态。") }
  }
}

actor SkinCommunityAPI {
  static let shared = SkinCommunityAPI()
  private let base = URL(string: "https://api.msime.app")!
  private let session: URLSession
  private let readCredentials: @Sendable () throws -> CommunityTokens?
  private let writeCredentials: @Sendable (CommunityTokens?) throws -> Void
  init(configuration: URLSessionConfiguration = .ephemeral,
       readCredentials: @escaping @Sendable () throws -> CommunityTokens? = { try CommunityCredentials.load() },
       writeCredentials: @escaping @Sendable (CommunityTokens?) throws -> Void = { try CommunityCredentials.save($0) }) {
    session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
    self.readCredentials = readCredentials
    self.writeCredentials = writeCredentials
  }
  private var refreshTask: Task<CommunityTokens, Error>?
  private var generation = 0

  func signedIn() throws -> Bool { try readCredentials() != nil }
  private func transport(_ path: String, method: String, body: Data?, token: String?) async throws -> (Data, Int) {
    guard let url = URL(string: path, relativeTo: base) else { throw CommunityFailure(message: "请求地址无效。") }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    request.timeoutInterval = 25
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse, data.count <= 1_000_000 else { throw CommunityFailure(message: "社区响应格式无效。") }
    return (data, response.statusCode)
  }
  private func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil, authenticated: Bool = false) async throws -> T {
    let tokens = (path == "/v1/auth/challenges" || path == "/v1/auth/login") ? nil : try readCredentials()
    if authenticated && tokens == nil { throw CommunityFailure(message: "请先使用 Apple 登录。") }
    var (data, status) = try await transport(path, method: method, body: body, token: tokens?.access_token)
    if status == 401, let tokens {
      let fresh = try await refresh(tokens)
      (data, status) = try await transport(path, method: method, body: body, token: fresh.access_token)
    }
    guard (200..<300).contains(status) else { throw Self.failure(data, status: status) }
    return try JSONDecoder().decode(T.self, from: status == 204 ? Data("{}".utf8) : data)
  }
  private func refresh(_ previous: CommunityTokens) async throws -> CommunityTokens {
    if let current = try readCredentials(), current.access_token != previous.access_token { return current }
    if let refreshTask { return try await refreshTask.value }
    let currentGeneration = generation
    let task = Task { () throws -> CommunityTokens in
      let body = try JSONSerialization.data(withJSONObject: ["refresh_token": previous.refresh_token])
      let (data, status) = try await self.transport("/v1/auth/refresh", method: "POST", body: body, token: nil)
      guard status == 200 else { throw Self.failure(data, status: status) }
      return try JSONDecoder().decode(CommunityTokens.self, from: data)
    }
    refreshTask = task
    defer { refreshTask = nil }
    let result = try await task.value
    guard currentGeneration == generation else { throw CancellationError() }
    try writeCredentials(result)
    return result
  }
  private static func failure(_ data: Data, status: Int) -> CommunityFailure {
    let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    let code = (root?["error"] as? [String: String])?["code"] ?? ""
    let message: String
    switch code {
    case "provider_disabled", "user_auth_disabled": message = "社区登录尚未启用，请稍后重试。"
    case "download_before_rating_or_own_skin": message = "下载使用后才能评分，且不能评价自己的作品。"
    case "skin_publish_limit": message = "最多发布 50 款皮肤，请先下架部分作品。"
    case "recent_login_required": message = "请退出并重新使用 Apple 登录后，再注销账号。"
    case "invalid_skin_design", "invalid_skin_metadata": message = "皮肤内容或名称不符合发布要求。"
    default:
      switch status {
      case 401: message = "登录已过期，请重新使用 Apple 登录。"
      case 404: message = "社区功能尚未上线，或这款皮肤已下架。"
      case 429: message = "操作较频繁，请稍后重试。"
      default: message = "社区暂时不可用，请稍后重试。"
      }
    }
    return CommunityFailure(message: message)
  }
  func challenge() async throws -> CommunityChallenge {
    try await request("/v1/auth/challenges", method: "POST", body: JSONSerialization.data(withJSONObject: ["provider": "apple", "purpose": "login"]))
  }
  func login(challenge: String, identityToken: String) async throws {
    let result: CommunityTokens = try await request("/v1/auth/login", method: "POST", body: JSONSerialization.data(withJSONObject: ["challenge_id": challenge, "credential": identityToken]))
    generation += 1
    try writeCredentials(result)
  }
  func logout(deleteAccount: Bool = false) async throws {
    let _: [String: Bool] = try await request(deleteAccount ? "/v1/users/me" : "/v1/auth/logout", method: deleteAccount ? "DELETE" : "POST", body: deleteAccount ? nil : JSONSerialization.data(withJSONObject: ["all": false]), authenticated: true)
    generation += 1
    try writeCredentials(nil)
  }
  func clearExpiredLogin() throws { generation += 1; try writeCredentials(nil) }
  func list(offset: Int = 0, search: String = "") async throws -> CommunityPage {
    var parts = URLComponents()
    parts.path = "/v1/community/skins"
    parts.queryItems = [.init(name: "offset", value: String(offset)), .init(name: "q", value: search)]
    return try await request(parts.string!)
  }
  func detail(_ id: String) async throws -> CommunitySkin { try await request("/v1/community/skins/\(id)") }
  func publish(id: String, name: String, description: String, design: CustomKeyboardSkin) async throws {
    struct Payload: Encodable { let id: String; let name: String; let description: String; let design: CustomKeyboardSkin }
    let _: [String: String] = try await request("/v1/community/skins", method: "POST", body: JSONEncoder().encode(Payload(id: id, name: name, description: description, design: design.normalized)), authenticated: true)
  }
  func download(_ id: String) async throws -> CustomKeyboardSkin {
    struct Result: Decodable, Sendable { let design: CustomKeyboardSkin }
    let result: Result = try await request("/v1/community/skins/\(id)/download", method: "POST", body: Data("{}".utf8), authenticated: true)
    return result.design.normalized
  }
  func rate(_ id: String, stars: Int) async throws {
    let _: [String: Int] = try await request("/v1/community/skins/\(id)/rating", method: "PUT", body: JSONSerialization.data(withJSONObject: ["stars": stars]), authenticated: true)
  }
  func unpublish(_ id: String) async throws {
    let _: [String: Bool] = try await request("/v1/community/skins/\(id)", method: "DELETE", authenticated: true)
  }
}
