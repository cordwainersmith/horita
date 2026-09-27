import Foundation

@MainActor
final class MinuteTicker {
    private let model: AppModel
    private var task: Task<Void, Never>?

    init(model: AppModel) {
        self.model = model
    }

    func start() {
        task?.cancel()
        task = Task { [model] in
            while !Task.isCancelled {
                let now = Date()
                let boundary = Calendar.current.nextDate(after: now, matching: DateComponents(second: 0), matchingPolicy: .nextTime)
                    ?? now.addingTimeInterval(60)
                let delay = max(boundary.timeIntervalSince(now), 0) + 0.05
                try? await Task.sleep(for: .seconds(delay))
                if Task.isCancelled { break }
                model.now = Date()
            }
        }
    }

    func restart() {
        model.now = Date()
        start()
    }
}
