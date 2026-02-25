import Fluent
import Vapor

final class DeviceChannel: Model {

    static let schema = "PushDevice+PushChannel"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "deviceId")
    var device: PushDevice

    @Parent(key: "channelId")
    var channel: PushChannel

    init() { }

    init(id: UUID? = nil, device: PushDevice, channel: PushChannel) throws {
        self.id = id
        self.$device.id = try device.requireID()
        self.$channel.id = try channel.requireID()
    }
}
