import Foundation

@MainActor public struct TaskRetryScheduler: RetryScheduler {
    public init() {}
    public func schedule(after delay: TimeInterval, action: @escaping @MainActor () -> Void) -> any ScheduledAction {
        let task = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard !Task.isCancelled else { return }
            action()
        }
        return TaskAction(task)
    }
    private final class TaskAction: ScheduledAction {
        let task: Task<Void, Never>
        init(_ task: Task<Void, Never>) { self.task = task }
        func cancel() { task.cancel() }
        deinit { task.cancel() }
    }
}
