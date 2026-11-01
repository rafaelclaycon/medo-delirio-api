@testable import App
import XCTVapor
import Fluent
import Foundation

final class DeviceAnalyticsTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    private func signal(
        _ installId: String,
        model: String = "iPhone17,1",
        system: String = "iOS",
        version: String = "26.0",
        onMac: Bool = false,
        timeZone: String = "America/Sao_Paulo",
        at dateTime: String
    ) async throws {
        try await StillAliveSignal(
            installId: installId, modelName: model, systemName: system, systemVersion: version,
            isiOSAppOnMac: onMac, appVersion: "13.8", currentTimeZone: timeZone, dateTime: dateTime
        ).save(on: app.db)
    }

    private func daysAgo(_ days: Double) -> String {
        Date().addingTimeInterval(-days * 86_400).iso8601withFractionalSeconds
    }

    private func jsonObject(_ res: XCTHTTPResponse) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView))
    }

    // MARK: - device-analytics

    func testDeviceAnalyticsCountsDistinctInstallsInTheLast30Days() async throws {
        try await signal("a", version: "26.0", timeZone: "America/Sao_Paulo", at: daysAgo(1))
        try await signal("a", version: "26.1", timeZone: "America/Sao_Paulo", at: daysAgo(2))
        try await signal("b", version: "26.0.1", timeZone: "America/Sao_Paulo", at: daysAgo(3))
        try await signal("c", model: "iPad16,3", system: "iPadOS", version: "18.5", timeZone: "Europe/Lisbon", at: daysAgo(4))
        try await signal("d", model: "Mac14,2", version: "26.0", onMac: true, timeZone: "", at: daysAgo(5))
        try await signal("old", version: "17.0", timeZone: "Asia/Tokyo", at: daysAgo(40))
        try await signal("sim", model: "iPhone Simulator", version: "26.0", at: daysAgo(1))

        try await app.test(.GET, "api/v3/device-analytics/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try XCTUnwrap(try self.jsonObject(res) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["top_ios_versions", "top_device_models", "top_device_types", "top_timezones", "total_timezones_count"])

            let response = try res.content.decode(DeviceAnalyticsResponse.self)
            XCTAssertEqual(response.top_ios_versions.map { [$0.id, $0.major_version, "\($0.count)"] }, [["26", "26", "3"], ["18", "18", "1"]])
            XCTAssertEqual(response.top_device_models.first.map { [$0.id, $0.model_name, "\($0.count)"] }, ["iPhone17,1", "iPhone17,1", "2"])
            XCTAssertEqual(Set(response.top_device_models.dropFirst().map(\.model_name)), ["iPad16,3", "Mac14,2"])
            XCTAssertEqual(response.top_device_models.dropFirst().map(\.count), [1, 1])

            XCTAssertEqual(response.top_device_types.first.map { [$0.id, $0.device_type, "\($0.count)"] }, ["iPhone", "iPhone", "2"])
            XCTAssertEqual(Set(response.top_device_types.dropFirst().map(\.device_type)), ["iPad", "Mac"])
            XCTAssertEqual(response.top_device_types.dropFirst().map(\.count), [1, 1])

            XCTAssertEqual(response.top_timezones.map { [$0.id, $0.timezone, "\($0.count)"] }, [
                ["America/Sao_Paulo", "America/Sao_Paulo", "2"],
                ["Europe/Lisbon", "Europe/Lisbon", "1"]
            ])
            // Installs that reported a time zone, not distinct time zones.
            XCTAssertEqual(response.total_timezones_count, 3)
        }
    }

    func testDeviceAnalyticsKeepsTheTop10ModelsAndTimeZones() async throws {
        for i in 1...12 {
            for j in 0..<i {
                try await signal("install-\(i)-\(j)", model: "Model\(i)", timeZone: "Zone/\(i)", at: daysAgo(1))
            }
        }

        try await app.test(.GET, "api/v3/device-analytics/\(TestEnvironment.testPassword)") { res async throws in
            let response = try res.content.decode(DeviceAnalyticsResponse.self)
            XCTAssertEqual(response.top_device_models.map(\.model_name), (3...12).reversed().map { "Model\($0)" })
            XCTAssertEqual(response.top_timezones.map(\.timezone), (3...12).reversed().map { "Zone/\($0)" })
            XCTAssertEqual(response.total_timezones_count, 78)
        }
    }

    func testDeviceAnalyticsIsEmptyWithoutSignals() async throws {
        try await app.test(.GET, "api/v3/device-analytics/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(DeviceAnalyticsResponse.self)
            XCTAssertTrue(response.top_ios_versions.isEmpty)
            XCTAssertTrue(response.top_device_models.isEmpty)
            XCTAssertTrue(response.top_device_types.isEmpty)
            XCTAssertTrue(response.top_timezones.isEmpty)
            XCTAssertEqual(response.total_timezones_count, 0)
        }
    }

    // MARK: - device-model-history and all-device-model-names

    func testDeviceModelHistoryCoversEveryMonthWithItsShareOfTheTotal() async throws {
        try await signal("a", model: "iPhone17,1", at: "2026-08-10T10:00:00.000Z")
        try await signal("a", model: "iPhone17,1", at: "2026-08-20T10:00:00.000Z")
        try await signal("b", model: "iPhone15,2", at: "2026-08-15T10:00:00.000Z")
        try await signal("b", model: "iPhone15,2", at: "2026-09-15T10:00:00.000Z")
        try await signal("a", model: "iPhone17,1", at: "2026-10-01T10:00:00.000Z")
        try await signal("c", model: "iPhone17,1", at: "2026-10-02T10:00:00.000Z")
        try await signal("sim", model: "iPhone Simulator", at: "2026-07-01T10:00:00.000Z")

        try await app.test(.GET, "api/v3/device-model-history/iPhone17,1/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try XCTUnwrap(try self.jsonObject(res) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["model_name", "history"])
            let response = try res.content.decode(DeviceModelHistoryResponse.self)
            XCTAssertEqual(response.model_name, "iPhone17,1")
            XCTAssertEqual(response.history.map { "\($0.month) \($0.count)/\($0.total)" }, [
                "2026-08 1/2", "2026-09 0/1", "2026-10 2/2"
            ])
        }
    }

    func testDeviceModelHistoryTreatsTheNameAsAValue() async throws {
        try await signal("a", at: "2026-10-01T10:00:00.000Z")

        try await app.test(.GET, "api/v3/device-model-history/x'%20OR%20'1'='1/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(DeviceModelHistoryResponse.self)
            XCTAssertEqual(response.history.map { "\($0.month) \($0.count)/\($0.total)" }, ["2026-10 0/1"])
        }
    }

    func testAllDeviceModelNamesAreSortedWithoutSimulators() async throws {
        try await signal("a", model: "iPhone17,1", at: "2026-10-01T10:00:00.000Z")
        try await signal("b", model: "iPad16,3", at: "2026-10-01T10:00:00.000Z")
        try await signal("c", model: "iPhone17,1", at: "2026-10-02T10:00:00.000Z")
        try await signal("d", model: "", at: "2026-10-02T10:00:00.000Z")
        try await signal("sim", model: "iPad Simulator", at: "2026-10-02T10:00:00.000Z")

        try await app.test(.GET, "api/v3/all-device-model-names/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode([String].self), ["iPad16,3", "iPhone17,1"])
        }
    }

    // MARK: - ios-version-history, all-ios-versions and ios-version-device-breakdown

    func testIOSVersionHistoryGroupsByMajorVersion() async throws {
        try await signal("a", version: "26.0", at: "2026-09-10T10:00:00.000Z")
        try await signal("b", version: "18.6", at: "2026-09-11T10:00:00.000Z")
        try await signal("a", version: "26.1", at: "2026-10-01T10:00:00.000Z")
        try await signal("b", version: "26.0.1", at: "2026-10-02T10:00:00.000Z")
        try await signal("c", version: "26", at: "2026-10-03T10:00:00.000Z")
        try await signal("d", version: "18.7", at: "2026-11-01T10:00:00.000Z")

        try await app.test(.GET, "api/v3/ios-version-history/26/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try XCTUnwrap(try self.jsonObject(res) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["major_version", "history"])
            let response = try res.content.decode(IOSVersionHistoryResponse.self)
            XCTAssertEqual(response.major_version, "26")
            XCTAssertEqual(response.history.map { "\($0.month) \($0.count)/\($0.total)" }, [
                "2026-09 1/2", "2026-10 3/3", "2026-11 0/1"
            ])
        }
    }

    func testAllIOSVersionsAreSortedNumerically() async throws {
        try await signal("a", version: "26.0", at: "2026-10-01T10:00:00.000Z")
        try await signal("b", version: "9.3.5", at: "2026-10-01T10:00:00.000Z")
        try await signal("c", version: "18.6", at: "2026-10-01T10:00:00.000Z")
        try await signal("d", version: "18.7", at: "2026-10-01T10:00:00.000Z")
        try await signal("e", version: "", at: "2026-10-01T10:00:00.000Z")
        try await signal("sim", model: "iPhone Simulator", version: "27.0", at: "2026-10-01T10:00:00.000Z")

        try await app.test(.GET, "api/v3/all-ios-versions/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode([String].self), ["9", "18", "26"])
        }
    }

    func testIOSVersionDeviceBreakdownListsModelsByTotalAcrossEveryMonth() async throws {
        try await signal("a", model: "iPhone17,1", version: "26.0", at: "2026-09-10T10:00:00.000Z")
        try await signal("b", model: "iPhone17,1", version: "26.0", at: "2026-09-11T10:00:00.000Z")
        try await signal("a", model: "iPhone17,1", version: "26.1", at: "2026-10-01T10:00:00.000Z")
        try await signal("c", model: "iPhone15,2", version: "26.0", at: "2026-10-02T10:00:00.000Z")
        try await signal("d", model: "iPhone12,1", version: "18.6", at: "2026-08-01T10:00:00.000Z")

        try await app.test(.GET, "api/v3/ios-version-device-breakdown/26/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try XCTUnwrap(try self.jsonObject(res) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["major_version", "devices"])
            let response = try res.content.decode(IOSVersionDeviceBreakdownResponse.self)
            XCTAssertEqual(response.major_version, "26")
            XCTAssertEqual(response.devices.map(\.model_name), ["iPhone17,1", "iPhone15,2"])
            // Months come from every signal, so August shows up with zeros.
            XCTAssertEqual(response.devices.map { $0.history.map { "\($0.month) \($0.count)" } }, [
                ["2026-08 0", "2026-09 2", "2026-10 1"],
                ["2026-08 0", "2026-09 0", "2026-10 1"]
            ])
        }
    }

    func testIOSVersionDeviceBreakdownIsEmptyForAnUnknownVersion() async throws {
        try await signal("a", version: "26.0", at: "2026-10-01T10:00:00.000Z")

        try await app.test(.GET, "api/v3/ios-version-device-breakdown/99/\(TestEnvironment.testPassword)") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(IOSVersionDeviceBreakdownResponse.self)
            XCTAssertEqual(response.major_version, "99")
            XCTAssertTrue(response.devices.isEmpty)
        }
    }

    // MARK: - Passwords

    func testEveryDeviceRouteRejectsAWrongPassword() async throws {
        let paths = [
            "api/v3/device-analytics/wrong",
            "api/v3/device-model-history/iPhone17,1/wrong",
            "api/v3/all-device-model-names/wrong",
            "api/v3/ios-version-history/26/wrong",
            "api/v3/all-ios-versions/wrong",
            "api/v3/ios-version-device-breakdown/26/wrong"
        ]
        for path in paths {
            try await app.test(.GET, path) { res async in
                XCTAssertEqual(res.status, .forbidden, path)
            }
        }
    }
}
