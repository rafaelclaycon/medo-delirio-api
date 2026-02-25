import APNS

struct TypedNotification: APNSwiftNotification {
    let aps: APNSwiftPayload
    let type: String
}
