import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class ProAccess {
    static let shared = ProAccess()
    nonisolated static let productID = "com.bradZellman.MagicCuts.pro"

    enum State: Equatable { case checking, locked, unlocked }
    private(set) var state: State = .checking
    private(set) var product: Product?
    private(set) var isWorking = false
    var message: String?
    @ObservationIgnored private var observer: Task<Void, Never>?

    var unlocked: Bool { state == .unlocked }
    var developmentAccess: Bool { AppRuntime.hasDevelopmentProAccess }

    init(observeTransactions: Bool = true) {
        if observeTransactions {
            observer = Task { [weak self] in
                for await update in Transaction.updates {
                    guard let self else { return }
                    if case .verified(let transaction) = update {
                        await self.refresh()
                        await transaction.finish()
                    }
                }
            }
        }
    }

    deinit { observer?.cancel() }

    func load() async {
        await refresh()
        if !unlocked { await loadProduct() }
    }

    func refresh() async {
        state = await Self.hasEntitlement() ? .unlocked : .locked
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first { $0.id == Self.productID && $0.type == .nonConsumable }
            if product == nil { message = "Pro purchasing is not available right now. Try again, or restore an existing purchase." }
            else { message = nil }
        } catch { message = "The App Store couldn't load Pro. Check your connection and try again." }
    }

    func purchase() async {
        guard !isWorking else { return }
        guard let product else { await loadProduct(); return }
        isWorking = true; message = nil
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result,
                      transaction.productID == Self.productID,
                      transaction.productType == .nonConsumable,
                      transaction.revocationDate == nil else {
                    message = "This purchase couldn't be verified. Restore purchases or try again."
                    return
                }
                await refresh()
                await transaction.finish()
                if !unlocked { message = "Your purchase is still being confirmed. Try restoring it in a moment." }
            case .pending:
                message = "Your purchase is awaiting approval. Pro will unlock when the App Store confirms it."
            case .userCancelled: break
            @unknown default:
                message = "The App Store returned an unfamiliar purchase state. Try restoring your purchase."
            }
        } catch { message = "The purchase couldn't be completed. Try again or restore an existing purchase." }
    }

    func restore() async {
        guard !isWorking else { return }
        isWorking = true; message = nil
        defer { isWorking = false }
        do {
            try await AppStore.sync()
            await refresh()
            message = unlocked ? "Pro is restored." : "No Pro purchase was found for this Apple Account."
        } catch { message = "Purchases couldn't be restored. Check your connection and try again." }
    }

    static func require() async throws {
        guard await hasEntitlement() else { throw InstrumentError.requiresPro }
    }

    private static func hasEntitlement() async -> Bool {
        if AppRuntime.forcesLockedProForUITesting { return false }
        if AppRuntime.hasDevelopmentProAccess { return true }
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID,
               transaction.productType == .nonConsumable,
               transaction.revocationDate == nil { return true }
        }
        return false
    }
}
