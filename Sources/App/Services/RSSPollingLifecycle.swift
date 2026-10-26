import Vapor

final class RSSPollingLifecycle: LifecycleHandler, @unchecked Sendable {

    private var task: Task<Void, Never>?

    func didBoot(_ app: Application) throws {
        let service = RSSPollingService(app: app)
        let interval = Duration.seconds(RSSPollingService.pollingIntervalMinutes * 60)

        // Polls one after another: the next wait only starts once a check, including any
        // new episode notifications, has finished.
        task = Task {
            try? await Task.sleep(for: .seconds(5))
            while !Task.isCancelled {
                await service.checkForNewEpisode()
                try? await Task.sleep(for: interval)
            }
            app.logger.info("RSS poll: stopped")
        }

        app.logger.info("RSS polling scheduled every \(RSSPollingService.pollingIntervalMinutes) minutes")
    }

    func shutdown(_ app: Application) {
        task?.cancel()
    }
}
