import Foundation
import StoreKit

/// StoreKit 2 訂閱購買 + 交易監聽 + server 驗證
final class PremiumManager: ObservableObject {
    static let productId = "com.mangotime.premium.monthly"
    @Published var product: Product?
    @Published var premium = false
    @Published var busy = false
    @Published var loadFailed = false

    private var api: APIClient?
    private var listener: Task<Void, Never>?

    func attach(_ api: APIClient) {
        self.api = api
        if listener == nil { startListener() }
        Task { await load() }
        Task { await refreshFromServer() }
    }

    deinit { listener?.cancel() }

    func load() async {
        do {
            let products = try await Product.products(for: [Self.productId])
            await MainActor.run {
                product = products.first
                loadFailed = products.isEmpty
            }
        } catch {
            await MainActor.run { loadFailed = true }
        }
    }

    func purchase() async {
        guard let product else { return }
        await MainActor.run { busy = true }
        defer { Task { await MainActor.run { self.busy = false } } }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx = try checkVerified(verification)
                await verifyWithServer(tx)
                await tx.finish()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch { /* 買唔到——留喺免費版 */ }
    }

    func restore() async {
        await MainActor.run { busy = true }
        defer { Task { await MainActor.run { self.busy = false } } }
        // 拉返最新 entitlement
        for await result in Transaction.currentEntitlements {
            if let tx = try? checkVerified(result), tx.productID == Self.productId {
                await verifyWithServer(tx)
            }
        }
    }

    private func startListener() {
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let tx = try? self.checkVerified(result), tx.productID == Self.productId {
                    await self.verifyWithServer(tx)
                    await tx.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified(_, let err): throw err
        }
    }

    private func verifyWithServer(_ tx: Transaction) async {
        guard let api else { return }
        let sandbox = tx.environment == .sandbox
        if (try? await api.verifyPremium(transactionId: String(tx.id), sandbox: sandbox)) == true {
            await MainActor.run { premium = true }
        }
    }

    private func refreshFromServer() async {
        guard let api else { return }
        let ok = (try? await api.premiumStatus()) ?? false
        await MainActor.run { premium = ok }
    }
}
