import Vapor
import NIOCore
import Dispatch

struct RSSPollingLifecycle: LifecycleHandler {

    func didBoot(_ app: Application) throws {
        let intervalMinutes = RSSPollingService.pollingIntervalMinutes

        app.eventLoopGroup.next().scheduleRepeatedTask(
            initialDelay: .seconds(5),
            delay: .seconds(Int64(intervalMinutes * 60))
        ) { _ in
            DispatchQueue.global(qos: .utility).async {
                let service = RSSPollingService(app: app)
                service.checkForNewEpisode()
            }
        }

        app.logger.info("RSS polling scheduled every \(intervalMinutes) minutes")
    }
}
