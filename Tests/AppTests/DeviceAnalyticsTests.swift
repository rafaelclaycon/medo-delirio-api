@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

struct DeviceAnalyticsTests {

    private func signal(
        _ installId: String,
        model: String = "iPhone17,1",
        system: String = "iOS",
        version: String = "26.0",
        onMac: Bool = false,
        timeZone: String = "America/Sao_Paulo",
        at dateTime: String,
        on app: Application
    ) async throws {
        try await StillAliveSignal(
            installId: installId, modelName: model, systemName: system, systemVersion: version,
            isiOSAppOnMac: onMac, appVersion: "13.8", currentTimeZone: timeZone, dateTime: dateTime
        ).save(on: app.db)
    }

    private func daysAgo(_ days: Double) -> String {
        Date().addingTimeInterval(-days * 86_400).iso8601withFractionalSeconds
    }

    private func jsonObject(_ res: TestingHTTPResponse) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView))
    }

    // MARK: - device-analytics

    @Test func `Device analytics counts distinct installs in the last 30 days`() async throws {
        try await withTestApp { app in
            try await signal("a", version: "26.0", timeZone: "America/Sao_Paulo", at: daysAgo(1), on: app)
            try await signal("a", version: "26.1", timeZone: "America/Sao_Paulo", at: daysAgo(2), on: app)
            try await signal("b", version: "26.0.1", timeZone: "America/Sao_Paulo", at: daysAgo(3), on: app)
            try await signal("c", model: "iPad16,3", system: "iPadOS", version: "18.5", timeZone: "Europe/Lisbon", at: daysAgo(4), on: app)
            try await signal("d", model: "Mac14,2", version: "26.0", onMac: true, timeZone: "", at: daysAgo(5), on: app)
            try await signal("old", version: "17.0", timeZone: "Asia/Tokyo", at: daysAgo(40), on: app)
            try await signal("sim", model: "iPhone Simulator", version: "26.0", at: daysAgo(1), on: app)

            try await app.testing().test(.GET, "api/v3/device-analytics/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                let json = try #require(try self.jsonObject(res) as? [String: Any])
                #expect(Set(json.keys) == ["top_ios_versions", "top_device_models", "top_device_types", "top_timezones", "total_timezones_count"])

                let response = try res.content.decode(DeviceAnalyticsResponse.self)
                #expect(response.top_ios_versions.map { [$0.id, $0.major_version, "\($0.count)"] } == [["26", "26", "3"], ["18", "18", "1"]])
                #expect(response.top_device_models.first.map { [$0.id, $0.model_name, "\($0.count)"] } == ["iPhone17,1", "iPhone17,1", "2"])
                #expect(Set(response.top_device_models.dropFirst().map(\.model_name)) == ["iPad16,3", "Mac14,2"])
                #expect(response.top_device_models.dropFirst().map(\.count) == [1, 1])

                #expect(response.top_device_types.first.map { [$0.id, $0.device_type, "\($0.count)"] } == ["iPhone", "iPhone", "2"])
                #expect(Set(response.top_device_types.dropFirst().map(\.device_type)) == ["iPad", "Mac"])
                #expect(response.top_device_types.dropFirst().map(\.count) == [1, 1])

                #expect(response.top_timezones.map { [$0.id, $0.timezone, "\($0.count)"] } == [
                    ["America/Sao_Paulo", "America/Sao_Paulo", "2"],
                    ["Europe/Lisbon", "Europe/Lisbon", "1"]
                ])
                // Installs that reported a time zone, not distinct time zones.
                #expect(response.total_timezones_count == 3)
            }
        }
    }

    @Test func `Device analytics keeps the top 10 models and time zones`() async throws {
        try await withTestApp { app in
            for i in 1...12 {
                for j in 0..<i {
                    try await signal("install-\(i)-\(j)", model: "Model\(i)", timeZone: "Zone/\(i)", at: daysAgo(1), on: app)
                }
            }

            try await app.testing().test(.GET, "api/v3/device-analytics/\(TestEnvironment.testPassword)") { res async throws in
                let response = try res.content.decode(DeviceAnalyticsResponse.self)
                #expect(response.top_device_models.map(\.model_name) == (3...12).reversed().map { "Model\($0)" })
                #expect(response.top_timezones.map(\.timezone) == (3...12).reversed().map { "Zone/\($0)" })
                #expect(response.total_timezones_count == 78)
            }
        }
    }

    @Test func `Device analytics is empty without signals`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v3/device-analytics/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                let response = try res.content.decode(DeviceAnalyticsResponse.self)
                #expect(response.top_ios_versions.isEmpty)
                #expect(response.top_device_models.isEmpty)
                #expect(response.top_device_types.isEmpty)
                #expect(response.top_timezones.isEmpty)
                #expect(response.total_timezones_count == 0)
            }
        }
    }

    // MARK: - device-model-history and all-device-model-names

    @Test func `Device model history covers every month with its share of the total`() async throws {
        try await withTestApp { app in
            try await signal("a", model: "iPhone17,1", at: "2026-08-10T10:00:00.000Z", on: app)
            try await signal("a", model: "iPhone17,1", at: "2026-08-20T10:00:00.000Z", on: app)
            try await signal("b", model: "iPhone15,2", at: "2026-08-15T10:00:00.000Z", on: app)
            try await signal("b", model: "iPhone15,2", at: "2026-09-15T10:00:00.000Z", on: app)
            try await signal("a", model: "iPhone17,1", at: "2026-10-01T10:00:00.000Z", on: app)
            try await signal("c", model: "iPhone17,1", at: "2026-10-02T10:00:00.000Z", on: app)
            try await signal("sim", model: "iPhone Simulator", at: "2026-07-01T10:00:00.000Z", on: app)

            try await app.testing().test(.GET, "api/v3/device-model-history/iPhone17,1/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                let json = try #require(try self.jsonObject(res) as? [String: Any])
                #expect(Set(json.keys) == ["model_name", "history"])
                let response = try res.content.decode(DeviceModelHistoryResponse.self)
                #expect(response.model_name == "iPhone17,1")
                #expect(response.history.map { "\($0.month) \($0.count)/\($0.total)" } == [
                    "2026-08 1/2", "2026-09 0/1", "2026-10 2/2"
                ])
            }
        }
    }

    @Test func `Device model history treats the name as a value`() async throws {
        try await withTestApp { app in
            try await signal("a", at: "2026-10-01T10:00:00.000Z", on: app)

            try await app.testing().test(.GET, "api/v3/device-model-history/x'%20OR%20'1'='1/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                let response = try res.content.decode(DeviceModelHistoryResponse.self)
                #expect(response.history.map { "\($0.month) \($0.count)/\($0.total)" } == ["2026-10 0/1"])
            }
        }
    }

    @Test func `All device model names are sorted without simulators`() async throws {
        try await withTestApp { app in
            try await signal("a", model: "iPhone17,1", at: "2026-10-01T10:00:00.000Z", on: app)
            try await signal("b", model: "iPad16,3", at: "2026-10-01T10:00:00.000Z", on: app)
            try await signal("c", model: "iPhone17,1", at: "2026-10-02T10:00:00.000Z", on: app)
            try await signal("d", model: "", at: "2026-10-02T10:00:00.000Z", on: app)
            try await signal("sim", model: "iPad Simulator", at: "2026-10-02T10:00:00.000Z", on: app)

            try await app.testing().test(.GET, "api/v3/all-device-model-names/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode([String].self) == ["iPad16,3", "iPhone17,1"])
            }
        }
    }

    // MARK: - ios-version-history, all-ios-versions and ios-version-device-breakdown

    @Test func `iOS version history groups by major version`() async throws {
        try await withTestApp { app in
            try await signal("a", version: "26.0", at: "2026-09-10T10:00:00.000Z", on: app)
            try await signal("b", version: "18.6", at: "2026-09-11T10:00:00.000Z", on: app)
            try await signal("a", version: "26.1", at: "2026-10-01T10:00:00.000Z", on: app)
            try await signal("b", version: "26.0.1", at: "2026-10-02T10:00:00.000Z", on: app)
            try await signal("c", version: "26", at: "2026-10-03T10:00:00.000Z", on: app)
            try await signal("d", version: "18.7", at: "2026-11-01T10:00:00.000Z", on: app)

            try await app.testing().test(.GET, "api/v3/ios-version-history/26/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                let json = try #require(try self.jsonObject(res) as? [String: Any])
                #expect(Set(json.keys) == ["major_version", "history"])
                let response = try res.content.decode(IOSVersionHistoryResponse.self)
                #expect(response.major_version == "26")
                #expect(response.history.map { "\($0.month) \($0.count)/\($0.total)" } == [
                    "2026-09 1/2", "2026-10 3/3", "2026-11 0/1"
                ])
            }
        }
    }

    @Test func `All iOS versions are sorted numerically`() async throws {
        try await withTestApp { app in
            try await signal("a", version: "26.0", at: "2026-10-01T10:00:00.000Z", on: app)
            try await signal("b", version: "9.3.5", at: "2026-10-01T10:00:00.000Z", on: app)
            try await signal("c", version: "18.6", at: "2026-10-01T10:00:00.000Z", on: app)
            try await signal("d", version: "18.7", at: "2026-10-01T10:00:00.000Z", on: app)
            try await signal("e", version: "", at: "2026-10-01T10:00:00.000Z", on: app)
            try await signal("sim", model: "iPhone Simulator", version: "27.0", at: "2026-10-01T10:00:00.000Z", on: app)

            try await app.testing().test(.GET, "api/v3/all-ios-versions/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode([String].self) == ["9", "18", "26"])
            }
        }
    }

    @Test func `iOS version device breakdown lists models by total across every month`() async throws {
        try await withTestApp { app in
            try await signal("a", model: "iPhone17,1", version: "26.0", at: "2026-09-10T10:00:00.000Z", on: app)
            try await signal("b", model: "iPhone17,1", version: "26.0", at: "2026-09-11T10:00:00.000Z", on: app)
            try await signal("a", model: "iPhone17,1", version: "26.1", at: "2026-10-01T10:00:00.000Z", on: app)
            try await signal("c", model: "iPhone15,2", version: "26.0", at: "2026-10-02T10:00:00.000Z", on: app)
            try await signal("d", model: "iPhone12,1", version: "18.6", at: "2026-08-01T10:00:00.000Z", on: app)

            try await app.testing().test(.GET, "api/v3/ios-version-device-breakdown/26/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                let json = try #require(try self.jsonObject(res) as? [String: Any])
                #expect(Set(json.keys) == ["major_version", "devices"])
                let response = try res.content.decode(IOSVersionDeviceBreakdownResponse.self)
                #expect(response.major_version == "26")
                #expect(response.devices.map(\.model_name) == ["iPhone17,1", "iPhone15,2"])
                // Months come from every signal, so August shows up with zeros.
                #expect(response.devices.map { $0.history.map { "\($0.month) \($0.count)" } } == [
                    ["2026-08 0", "2026-09 2", "2026-10 1"],
                    ["2026-08 0", "2026-09 0", "2026-10 1"]
                ])
            }
        }
    }

    @Test func `iOS version device breakdown is empty for an unknown version`() async throws {
        try await withTestApp { app in
            try await signal("a", version: "26.0", at: "2026-10-01T10:00:00.000Z", on: app)

            try await app.testing().test(.GET, "api/v3/ios-version-device-breakdown/99/\(TestEnvironment.testPassword)") { res async throws in
                #expect(res.status == .ok)
                let response = try res.content.decode(IOSVersionDeviceBreakdownResponse.self)
                #expect(response.major_version == "99")
                #expect(response.devices.isEmpty)
            }
        }
    }

    // MARK: - Passwords

    @Test(arguments: [
        "api/v3/device-analytics/wrong",
        "api/v3/device-model-history/iPhone17,1/wrong",
        "api/v3/all-device-model-names/wrong",
        "api/v3/ios-version-history/26/wrong",
        "api/v3/all-ios-versions/wrong",
        "api/v3/ios-version-device-breakdown/26/wrong"
    ])
    func `Every device route rejects a wrong password`(path: String) async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, path) { res async in
                #expect(res.status == .forbidden)
            }
        }
    }
}
