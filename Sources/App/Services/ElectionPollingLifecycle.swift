import Vapor

final class ElectionPollingLifecycle: LifecycleHandler, @unchecked Sendable {

    private var task: Task<Void, Never>?

    func didBoot(_ app: Application) throws {
        let service = ElectionPollingService(app: app)
        task = Task {
            await service.run()
        }
        app.logger.info("Election polling scheduled every \(Int(ElectionPollingService.pollingInterval)) seconds")
    }

    func shutdown(_ app: Application) {
        task?.cancel()
    }
}
