import XCTest
import UIKit

private final class CommunityMemoryCredentials: @unchecked Sendable {
  private let lock = NSLock()
  private var tokens: CommunityTokens?
  func read() -> CommunityTokens? { lock.lock(); defer { lock.unlock() }; return tokens }
  func write(_ value: CommunityTokens?) { lock.lock(); defer { lock.unlock() }; tokens = value }
}

private final class CommunityFixtureProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let path = request.url!.path
    let body: String
    let status: Int
    if path == "/v1/auth/challenges" {
      body = #"{"challenge_id":"fixture-id","nonce":"server-nonce"}"#; status = 200
    } else if path == "/v1/auth/login" || path == "/v1/auth/refresh" {
      let token = path.hasSuffix("refresh") ? "fresh" : "expired"
      body = "{\"access_token\":\"\(token)\",\"refresh_token\":\"refresh-fixture\",\"user\":{\"id\":\"fixture-user\",\"display_name\":\"测试\"}}"
      status = 200
    } else if path == "/v1/auth/logout" {
      body = ""; status = 204
    } else if request.value(forHTTPHeaderField: "Authorization") == "Bearer expired" {
      body = #"{"error":{"code":"invalid_credentials"}}"#; status = 401
    } else if request.url?.query?.contains("offset=20") == true {
      body = #"{"error":{"code":"rate_limit_exceeded","message":"internal"}}"#; status = 429
    } else {
      body = #"{"skins":[{"id":"a1234567-1234-1234-1234-123456789abc","name":"测试","description":"示例","author":"作者","design":{"background":15266027,"keyBackground":16777215,"keyForeground":1516829,"accent":1596487,"actionBackground":1596487,"cornerRadius":8,"borderWidth":0,"shadow":0,"pattern":0,"monospaced":false},"downloads":2,"rating_count":1,"rating_average":4,"owned":false,"my_rating":0}],"has_more":false}"#
      status = 200
    }
    client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

final class SkinCommunityTests: XCTestCase {
  func testCommunityWireFormatAndErrors() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CommunityFixtureProtocol.self]
    let api = SkinCommunityAPI(configuration: configuration, readCredentials: { nil }, writeCredentials: { _ in })
    let page = try await api.list(search: "纸感 & 星光")
    XCTAssertEqual(page.skins.first?.downloads, 2)
    XCTAssertEqual(page.skins.first?.rating_average, 4)
    XCTAssertNil(page.skins.first?.design.photo)
    XCTAssertFalse(page.has_more)
    let challenge = try await api.challenge()
    XCTAssertEqual(challenge.nonce, "server-nonce")
    do { _ = try await api.list(offset: 20); XCTFail("expected limit error") }
    catch { XCTAssertEqual(error.localizedDescription, "操作较频繁，请稍后重试。") }
  }
  func testLoginConcurrentRefreshAndEmptyLogoutResponse() async throws {
    let memory = CommunityMemoryCredentials()
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CommunityFixtureProtocol.self]
    let api = SkinCommunityAPI(configuration: configuration, readCredentials: { memory.read() }, writeCredentials: { memory.write($0) })
    try await api.login(challenge: "fixture", identityToken: "synthetic")
    let signedIn = try await api.signedIn()
    XCTAssertTrue(signedIn)
    try await withThrowingTaskGroup(of: Void.self) { group in
      for _ in 0..<8 { group.addTask { _ = try await api.list() } }
      try await group.waitForAll()
    }
    XCTAssertEqual(memory.read()?.access_token, "fresh")
    try await api.logout()
    let signedOut = try await api.signedIn()
    XCTAssertFalse(signedOut)
  }
  @MainActor func testCommunityPreviewDoesNotChangeActiveDesign() throws {
    let previous = CustomKeyboardSkinStore.current
    let backdrop = KeyboardSkinBackgroundView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
    var design = CustomKeyboardSkin.templates[2].1
    design.pattern = 2
    backdrop.designOverride = design
    backdrop.skin = .custom
    let before = UIGraphicsImageRenderer(bounds: backdrop.bounds).image { backdrop.layer.render(in: $0.cgContext) }.pngData()
    design.background = 0xEEFFFF
    design.gradientEnd = nil
    backdrop.designOverride = design
    backdrop.skin = .custom
    let after = UIGraphicsImageRenderer(bounds: backdrop.bounds).image { backdrop.layer.render(in: $0.cgContext) }.pngData()
    XCTAssertNotEqual(before, after)
    XCTAssertEqual(CustomKeyboardSkinStore.current, previous)
    XCTAssertEqual(CustomKeyboardSkin.rgb(try XCTUnwrap(backdrop.backgroundColor)), design.background)
  }
}
