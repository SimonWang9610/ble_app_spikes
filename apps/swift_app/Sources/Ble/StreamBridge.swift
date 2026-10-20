/// Re-wraps a binding stream so the binding object stays alive while it is consumed,
/// and is closed when the consumer stops (its task is cancelled or the loop ends).
func bridge<T: Sendable>(
    _ items: AsyncStream<T>,
    close: @escaping @Sendable () -> Void
) -> AsyncStream<T> {
    AsyncStream { continuation in
        let task = Task {
            for await item in items { continuation.yield(item) }
            continuation.finish()
        }
        continuation.onTermination = { _ in
            task.cancel()
            close()
        }
    }
}
