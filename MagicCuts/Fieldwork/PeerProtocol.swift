import Foundation
import Network
import CryptoKit

nonisolated enum PeerMessageKind: String, Codable, Sendable {
    case hello, confirmed, ping, pong, upload, uploaded, download, downloaded, nearbyToken, nearbyStop
}

nonisolated struct PeerMessage: Codable, Sendable {
    var version = 1
    var id = UUID()
    var kind: PeerMessageKind
    var replyTo: UUID?
    var payload: Data?
    var digest: String?
    var isValid: Bool {
        guard version == 1 else { return false }
        switch kind {
        case .hello: return payload?.count == 32 && replyTo == nil
        case .upload, .downloaded: return payload?.count == PeerProtocol.transferBytes
        case .nearbyToken: return (payload?.count ?? 0) > 0 && (payload?.count ?? 0) <= 16_384
        default: return payload == nil && (digest?.count ?? 0) <= 64
        }
    }
}

nonisolated enum PeerProtocol {
    static let maximumFrameBytes = 4 * 1024 * 1024
    static let transferBytes = 2 * 1024 * 1024
    static let service = "_magiccuts._tcp"
    static var tcpParameters: NWParametersBuilder<TCP> {
        // Bonjour supplies the nearby endpoint. A link-local-only listener rejects simulator
        // bridge/loopback peers; prohibit cellular while allowing Wi-Fi and wired participants.
        NWParametersBuilder<TCP>.parameters { TCP() }.peerToPeerIncluded(true).prohibitedInterfaceTypes([.cellular])
    }
    static func frame(_ data: Data) throws -> Data {
        guard !data.isEmpty, data.count <= maximumFrameBytes else { throw PeerError.invalidFrame }
        let count = UInt32(data.count)
        var framed = Data([UInt8(count >> 24), UInt8(truncatingIfNeeded: count >> 16), UInt8(truncatingIfNeeded: count >> 8), UInt8(truncatingIfNeeded: count)])
        framed.append(data); return framed
    }
    static func length(_ data: Data) throws -> Int {
        guard data.count == 4 else { throw PeerError.invalidFrame }
        let count = data.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard count > 0, count <= maximumFrameBytes else { throw PeerError.invalidFrame }
        return Int(count)
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func testData() -> Data { Data((0..<transferBytes).map { UInt8(truncatingIfNeeded: $0 &* 73 &+ 19) }) }
}

nonisolated enum PeerError: LocalizedError, Sendable {
    case invalidFrame, invalidMessage, ended, timeout, unconfirmed, integrity, replay
    var errorDescription: String? {
        switch self {
        case .invalidFrame: "The peer sent an invalid or oversized frame."
        case .invalidMessage: "The peer sent an unsupported message."
        case .ended: "The peer connection ended. Reconnect both devices to continue."
        case .timeout: "The peer did not respond within the test's time limit."
        case .unconfirmed: "Confirm the matching connection code on both devices first."
        case .integrity: "The returned test bytes did not match. This result was excluded."
        case .replay: "The peer message sequence was invalid. Reconnect both devices."
        }
    }
}

// An ephemeral key exchange protects discovery tokens and test traffic. Both users verify the derived code.
nonisolated struct PeerCipher: Sendable {
    private let privateKey: Curve25519.KeyAgreement.PrivateKey
    private var sendingKey: SymmetricKey?
    private var receivingKey: SymmetricKey?
    private var sendSequence: UInt64 = 0
    private var receiveSequence: UInt64 = 0
    var publicKey: Data { privateKey.publicKey.rawRepresentation }
    init() { privateKey = Curve25519.KeyAgreement.PrivateKey() }
    mutating func establish(peerKey: Data) throws -> String {
        guard sendingKey == nil, peerKey.count == 32, peerKey != publicKey else { throw PeerError.invalidMessage }
        let peer = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerKey)
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: peer)
        let localFirst = publicKey.lexicographicallyPrecedes(peerKey)
        let context = localFirst ? publicKey + peerKey : peerKey + publicKey
        let base = secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data("MagicCuts peer v1".utf8), sharedInfo: context, outputByteCount: 32)
        let first = HKDF<SHA256>.deriveKey(inputKeyMaterial: base, info: Data("first to second".utf8), outputByteCount: 32)
        let second = HKDF<SHA256>.deriveKey(inputKeyMaterial: base, info: Data("second to first".utf8), outputByteCount: 32)
        sendingKey = localFirst ? first : second; receivingKey = localFirst ? second : first
        let bytes = base.withUnsafeBytes { Data($0) }
        let digest = SHA256.hash(data: Data("confirm".utf8) + context + bytes)
        let number = digest.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) } % 1_000_000
        return String(format: "%06u", number)
    }
    mutating func seal(_ data: Data) throws -> Data {
        guard let sendingKey, sendSequence < UInt64.max else { throw PeerError.unconfirmed }
        let sequence = Self.bytes(sendSequence)
        let box = try ChaChaPoly.seal(data, using: sendingKey, authenticating: sequence)
        sendSequence += 1
        return Data([1]) + sequence + box.combined
    }
    mutating func open(_ data: Data) throws -> Data {
        guard let receivingKey, data.count >= 37, data.first == 1 else { throw PeerError.invalidFrame }
        let sequence = Data(data.dropFirst().prefix(8))
        let number = sequence.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        guard number == receiveSequence, receiveSequence < UInt64.max else { throw PeerError.replay }
        let box = try ChaChaPoly.SealedBox(combined: data.dropFirst(9))
        let result = try ChaChaPoly.open(box, using: receivingKey, authenticating: sequence)
        receiveSequence += 1
        return result
    }
    private static func bytes(_ value: UInt64) -> Data { Data((0..<8).reversed().map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }) }
}

actor PeerLink {
    let connection: NetworkConnection<TCP>
    private var cipher = PeerCipher()
    private var sends: Task<Void, Error>?
    private var stopped = false
    private var established = false
    init(connection: NetworkConnection<TCP>) { self.connection = connection }
    func sendHello() async throws {
        let message = PeerMessage(kind: .hello, payload: cipher.publicKey)
        try await write(Data([0]) + JSONEncoder().encode(message))
    }
    func acceptHello(_ data: Data) throws -> String {
        guard !established, data.count <= 2048, data.first == 0 else { throw PeerError.invalidMessage }
        let message = try JSONDecoder().decode(PeerMessage.self, from: data.dropFirst())
        guard message.isValid, message.kind == .hello, let key = message.payload else { throw PeerError.invalidMessage }
        let code = try cipher.establish(peerKey: key); established = true; return code
    }
    func send(_ message: PeerMessage) async throws {
        guard !stopped, message.isValid, message.kind != .hello else { throw PeerError.invalidMessage }
        let encoded = try JSONEncoder().encode(message)
        let encrypted = try cipher.seal(encoded)
        try await write(encrypted)
    }
    func receiveHello() async throws -> String { try acceptHello(await read()) }
    func receive() async throws -> PeerMessage {
        let encrypted = try await read()
        let data = try cipher.open(encrypted)
        let message = try JSONDecoder().decode(PeerMessage.self, from: data)
        guard message.isValid, message.kind != .hello else { throw PeerError.invalidMessage }
        return message
    }
    private func write(_ data: Data) async throws {
        guard !stopped else { throw PeerError.ended }
        let frame = try PeerProtocol.frame(data), previous = sends, connection = connection
        let send = Task {
            if let previous { try await previous.value }
            try Task.checkCancellation(); try await connection.send(frame)
        }
        sends = send
        try await withTaskCancellationHandler { try await send.value } onCancel: { send.cancel() }
    }
    private func read() async throws -> Data {
        guard !stopped else { throw PeerError.ended }
        let header = try await connection.receive(exactly: 4)
        guard header.content.count == 4 else { throw PeerError.ended }
        let count = try PeerProtocol.length(header.content)
        let message = try await connection.receive(exactly: count)
        guard message.content.count == count else { throw PeerError.ended }
        return message.content
    }
    func stop() { stopped = true; sends?.cancel(); sends = nil }
    func path() -> NWPath? { connection.currentPath }
}
