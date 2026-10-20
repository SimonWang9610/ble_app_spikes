/// Retries after a link loss until the link and every subscription are back, or 60 s pass.
/// Talks only to its session, which does the actual work.
@MainActor
final class Reconnector {
    private static let delays: [Double] = [1, 2, 4, 8, 10]
    private static let limit: Double = 60

    private unowned let session: DeviceSession
    private var task: Task<Void, Never>?

    init(session: DeviceSession) {
        self.session = session
    }

    func start() {
        task?.cancel()
        task = Task { await retry() }
    }

    /// Cancels the loop: it ends before its next attempt or out of its delay.
    func stop() {
        task?.cancel()
        task = nil
    }

    private func retry() async {
        let start = ContinuousClock.now
        var attempt = 0
        do {
            while !Task.isCancelled {
                attempt += 1
                if try await self.attempt(attempt) {
                    session.reconnected(after: (ContinuousClock.now - start).seconds)
                    return
                }
                let delay = Self.delays[min(attempt - 1, Self.delays.count - 1)]
                if (ContinuousClock.now - start).seconds + delay > Self.limit {
                    session.gaveUp(reason: "gave up reconnecting after \(Int(Self.limit)) s")
                    Log.error("Gave up reconnecting")
                    return
                }
                try await Task.sleep(for: .seconds(delay))
            }
        } catch {}
    }

    /// One try. A failed one closes its half-open link, so nothing of it survives into the next.
    /// Rethrows the `CancellationError` of an attempt that Disconnect overtook.
    private func attempt(_ attempt: Int) async throws -> Bool {
        session.reconnecting(attempt)
        Log.event("Reconnecting, attempt \(attempt)")
        do {
            try await session.establish()
            return true
        } catch let error as CancellationError {
            throw error
        } catch {
            Log.error("Reconnect attempt \(attempt) failed: \(describe(error))")
        }
        await session.dropAttempt()
        return false
    }
}
