/// Waits for a condition the app reaches on its own tasks.
@MainActor
func eventually(within timeout: Duration = .seconds(2), _ condition: () -> Bool) async -> Bool {
    let end = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < end else { return false }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return true
}
