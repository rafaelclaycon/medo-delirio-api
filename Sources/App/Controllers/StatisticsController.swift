//
//  StatisticsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor
import SQLiteNIO

struct StatisticsController {

    // MARK: - GET

    func getAllClientDeviceInfoHandlerV1(req: Request) -> EventLoopFuture<[ClientDeviceInfo]> {
        return ClientDeviceInfo.query(on: req.db).all()
    }

    func getAllSoundShareCountStatsHandlerV1(req: Request) -> EventLoopFuture<[ShareCountStat]> {
        return ShareCountStat.query(on: req.db).all()
    }

    func getInstallIdCountHandlerV1(req: Request) -> EventLoopFuture<[Int]> {
        if let sqlite = req.db as? SQLiteDatabase {
            let query = """
                select count(c.installId) totalCount
                from ClientDeviceInfo c
                where c.installId not in ("0A4D4541-BC16-4C15-842E-DA6ACF957027","0F1DF136-BECC-4216-ABF5-BC05C91FBB5B","A93E5354-41F9-5170-AFD9-817FAE37D037","F60AF930-0CBA-41FF-A80E-1E6007ED6AE8","F4B0E5C6-32AA-4EA3-BD32-01EE9AD611F4","FC2ADC6B-B70E-4B69-BC69-CCCADB64903F","F32538E4-6422-4D6F-9490-0984C17B7D80","285EAE4D-FBDE-482B-B8F2-705A68A67FDC","C78A6C1E-4EE0-521F-9C9E-F9AD9CA6C51D","04BCE1A6-5885-47D7-AD61-A14D6D6B61B7","C0821365-0003-4986-91EE-F9F79CDF4E7A","7CC49574-5275-4490-864B-65551784131F","DFD4128B-65C3-4251-9948-DC85D6E83FBE","E8120B41-E486-4170-95E0-5F13737A85AB","173BF7C0-CDF9-4A8D-A1B9-F91611AA12FF","93AC7BAB-9E30-4219-A0E8-04B4AD8F009C","AE87DEEA-23BD-4FFD-B918-63B572CD165C")
                and c.modelName not like '%Simulator%';
            """
            
            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(row.column("totalCount")?.integer ?? 0)
            }
        } else {
            return req.eventLoop.makeSucceededFuture([0])
        }
    }

    func getSoundShareCountStatsAllTimeHandlerV2(req: Request) -> EventLoopFuture<[ShareCountStat]> {
        if let sqlite = req.db as? SQLiteDatabase {
            let query = """
                select s.contentId, sum(s.shareCount) totalShareCount
                from ShareCountStat s
                where s.contentType in (0,2)
                group by s.contentId
                order by totalShareCount desc
                limit 10
            """
            
            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(ShareCountStat(installId: "", contentId: row.column("contentId")?.string ?? "", contentType: 0, shareCount: row.column("totalShareCount")?.integer ?? 0, dateTime: row.column("date")?.string ?? Date().iso8601withFractionalSeconds))
            }
        } else {
            return req.eventLoop.makeSucceededFuture([ShareCountStat]())
        }
    }

    func getSoundShareCountStatsFromHandlerV2(req: Request) throws -> EventLoopFuture<[ShareCountStat]> {
        guard let date = req.parameters.get("date") else {
            throw Abort(.badRequest, reason: "Missing date parameter.")
        }
        
        if let sqlite = req.db as? SQLiteDatabase {
            let query = """
                select s.contentId, sum(s.shareCount) totalShareCount
                from ShareCountStat s
                where s.contentType in (0,2)
                and s.dateTime > '\(date)'
                group by s.contentId
                order by totalShareCount desc
                limit 10
            """
            
            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(
                    ShareCountStat(
                        installId: "",
                        contentId: row.column("contentId")?.string ?? "",
                        contentType: 0,
                        shareCount: row.column("totalShareCount")?.integer ?? 0,
                        dateTime: row.column("date")?.string ?? Date().iso8601withFractionalSeconds
                    )
                )
            }
        } else {
            return req.eventLoop.makeSucceededFuture([])
        }
    }

    func getSoundShareCountStatsAllTimeHandlerV3(req: Request) -> EventLoopFuture<[TopChartItem]> {
        if let sqlite = req.db as? SQLiteDatabase {
            let query = """
                select s.contentId, c.title as contentName, a.id as authorId, a.name as authorName, sum(s.shareCount) totalShareCount
                from ShareCountStat s
                inner join MedoContent c on c.id = s.contentId
                inner join Author a on c.authorId = a.id
                where s.contentType in (0,2)
                group by s.contentId
                order by totalShareCount desc
                limit 10
            """

            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(
                    TopChartItem(
                        rankNumber: "",
                        contentId: row.column("contentId")?.string ?? "",
                        contentName: row.column("contentName")?.string ?? "",
                        contentAuthorId: row.column("authorId")?.string ?? "",
                        contentAuthorName: row.column("authorName")?.string ?? "",
                        shareCount: row.column("totalShareCount")?.integer ?? 0
                    )
                )
            }
        } else {
            return req.eventLoop.makeSucceededFuture([])
        }
    }

    func getSoundShareCountStatsFromHandlerV3(req: Request) throws -> EventLoopFuture<[TopChartItem]> {
        guard let date = req.parameters.get("date") else {
            throw Abort(.badRequest, reason: "Missing date parameter.")
        }

        if let sqlite = req.db as? SQLiteDatabase {
            let query = """
                select s.contentId, c.title as contentName, a.id as authorId, a.name as authorName, sum(s.shareCount) totalShareCount
                from ShareCountStat s
                inner join MedoContent c on c.id = s.contentId
                inner join Author a on c.authorId = a.id
                where s.contentType in (0,2)
                and s.dateTime > '\(date)'
                group by s.contentId
                order by totalShareCount desc
                limit 10
            """

            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(
                    TopChartItem(
                        rankNumber: "",
                        contentId: row.column("contentId")?.string ?? "",
                        contentName: row.column("contentName")?.string ?? "",
                        contentAuthorId: row.column("authorId")?.string ?? "",
                        contentAuthorName: row.column("authorName")?.string ?? "",
                        shareCount: row.column("totalShareCount")?.integer ?? 0
                    )
                )
            }
        } else {
            return req.eventLoop.makeSucceededFuture([])
        }
    }

    func getSoundShareCountStatsFromToHandlerV3(req: Request) throws -> EventLoopFuture<[TopChartItem]> {
        guard 
            let firstDate = req.parameters.get("firstDate"),
            let secondDate = req.parameters.get("secondDate")
        else {
            throw Abort(.badRequest, reason: "Missing date parameters.")
        }

        if let sqlite = req.db as? SQLiteDatabase {
            let query = """
                select s.contentId, c.title as contentName, a.id as authorId, a.name as authorName, sum(s.shareCount) totalShareCount
                from ShareCountStat s
                inner join MedoContent c on c.id = s.contentId
                inner join Author a on c.authorId = a.id
                where s.contentType in (0,2)
                and s.dateTime between '\(firstDate)' and '\(secondDate)'
                group by s.contentId
                order by totalShareCount desc
                limit 10
            """

            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(
                    TopChartItem(
                        rankNumber: "",
                        contentId: row.column("contentId")?.string ?? "",
                        contentName: row.column("contentName")?.string ?? "",
                        contentAuthorId: row.column("authorId")?.string ?? "",
                        contentAuthorName: row.column("authorName")?.string ?? "",
                        shareCount: row.column("totalShareCount")?.integer ?? 0
                    )
                )
            }
        } else {
            return req.eventLoop.makeSucceededFuture([])
        }
    }

    func getSoundShareCountStatsForSoundIdHandler(req: Request) -> EventLoopFuture<ContentShareCountStats> {
        guard let soundId = req.parameters.get("soundId") else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Missing soundId parameter"))
        }

        if let sqlite = req.db as? SQLiteDatabase {
            let shareCountQuery = """
                SELECT
                    SUM(CASE WHEN s.dateTime >= date('now', '-7 days') THEN s.shareCount ELSE 0 END) AS lastWeekShareCount,
                    SUM(s.shareCount) AS totalShareCount
                FROM ShareCountStat s
                WHERE s.contentId = '\(soundId)' AND s.contentType IN (0, 2)
            """

            let monthYearQuery = """
                SELECT
                    strftime('%Y', s.dateTime) AS year,
                    strftime('%m', s.dateTime) AS month,
                    SUM(s.shareCount) AS totalShareCount
                FROM ShareCountStat s
                WHERE s.contentId = '\(soundId)' AND s.contentType IN (0, 2)
                GROUP BY year, month
                ORDER BY totalShareCount DESC
                LIMIT 1
            """

            let shareCountFuture = sqlite.query(shareCountQuery)
            let monthYearFuture = sqlite.query(monthYearQuery)

            return shareCountFuture.and(monthYearFuture).flatMapThrowing { shareCountRows, monthYearRows in
                // Processing the all-time and last-week share counts
                guard let shareCountRow = shareCountRows.first else {
                    throw Abort(.notFound, reason: "No stats found for soundId \(soundId)")
                }
                let totalShareCount = shareCountRow.column("totalShareCount")?.integer ?? 0
                let lastWeekShareCount = shareCountRow.column("lastWeekShareCount")?.integer ?? 0

                // Processing the month and year with the most share counts
                guard let monthYearRow = monthYearRows.first else {
                    throw Abort(.notFound, reason: "No month-year stats found for soundId \(soundId)")
                }
                let year = monthYearRow.column("year")?.string ?? ""
                let month = monthYearRow.column("month")?.string ?? ""

                return ContentShareCountStats(
                    totalShareCount: totalShareCount,
                    lastWeekShareCount: lastWeekShareCount,
                    topMonth: month,
                    topYear: year
                )
            }
        } else {
            return req.eventLoop.makeSucceededFuture(
                ContentShareCountStats(
                    totalShareCount: 0,
                    lastWeekShareCount: 0,
                    topMonth: "",
                    topYear: ""
                )
            )
        }
    }

    // MARK: - POST

    func postShareCountStatHandlerV1(req: Request) throws -> EventLoopFuture<ShareCountStat> {
        let stat = try req.content.decode(ShareCountStat.self)
        return stat.save(on: req.db).map {
            stat
        }
    }

    func postSharedToBundleIdHandlerV1(req: Request) throws -> EventLoopFuture<ShareBundleIdLog> {
        let log = try req.content.decode(ShareBundleIdLog.self)
        return log.save(on: req.db).map {
            log
        }
    }
}

// MARK: - Songs

extension StatisticsController {

    func getSongShareCountStatsAllTimeHandlerV3(req: Request) -> EventLoopFuture<[TopChartItem]> {
        if let sqlite = req.db as? SQLiteDatabase {
            let query = """
                select s.contentId, c.title as contentName, mg.name as musicGenre, sum(s.shareCount) totalShareCount
                from ShareCountStat s
                inner join MedoContent c on c.id = s.contentId
                inner join MusicGenre mg on mg.id = c.musicGenre
                where s.contentType in (1,3)
                group by s.contentId
                order by totalShareCount desc
                limit 10
            """

            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(
                    TopChartItem(
                        rankNumber: "",
                        contentId: row.column("contentId")?.string ?? "",
                        contentName: row.column("contentName")?.string ?? "",
                        contentAuthorId: "",
                        contentAuthorName: row.column("musicGenre")?.string ?? "",
                        shareCount: row.column("totalShareCount")?.integer ?? 0
                    )
                )
            }
        } else {
            return req.eventLoop.makeSucceededFuture([])
        }
    }

    func getSongShareCountStatsFromHandlerV3(req: Request) throws -> EventLoopFuture<[TopChartItem]> {
        guard let date = req.parameters.get("date") else {
            throw Abort(.badRequest, reason: "Missing date parameter.")
        }

        if let sqlite = req.db as? SQLiteDatabase {
            let query = """
                select s.contentId, c.title as contentName, mg.name as musicGenre, sum(s.shareCount) totalShareCount
                from ShareCountStat s
                inner join MedoContent c on c.id = s.contentId
                inner join MusicGenre mg on mg.id = c.musicGenre
                where s.contentType in (1,3)
                and s.dateTime > '\(date)'
                group by s.contentId
                order by totalShareCount desc
                limit 10
            """

            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(
                    TopChartItem(
                        rankNumber: "",
                        contentId: row.column("contentId")?.string ?? "",
                        contentName: row.column("contentName")?.string ?? "",
                        contentAuthorId: "",
                        contentAuthorName: row.column("musicGenre")?.string ?? "",
                        shareCount: row.column("totalShareCount")?.integer ?? 0
                    )
                )
            }
        } else {
            return req.eventLoop.makeSucceededFuture([])
        }
    }

    func getSongShareCountStatsFromToHandlerV3(req: Request) throws -> EventLoopFuture<[TopChartItem]> {
        guard
            let firstDate = req.parameters.get("firstDate"),
            let secondDate = req.parameters.get("secondDate")
        else {
            throw Abort(.badRequest, reason: "Missing date parameters.")
        }

        if let sqlite = req.db as? SQLiteDatabase {
            let query = """
                select s.contentId, c.title as contentName, mg.name as musicGenre, sum(s.shareCount) totalShareCount
                from ShareCountStat s
                inner join MedoContent c on c.id = s.contentId
                inner join MusicGenre mg on mg.id = c.musicGenre
                where s.contentType in (1,3)
                and s.dateTime between '\(firstDate)' and '\(secondDate)'
                group by s.contentId
                order by totalShareCount desc
                limit 10
            """

            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(
                    TopChartItem(
                        rankNumber: "",
                        contentId: row.column("contentId")?.string ?? "",
                        contentName: row.column("contentName")?.string ?? "",
                        contentAuthorId: "",
                        contentAuthorName: row.column("musicGenre")?.string ?? "",
                        shareCount: row.column("totalShareCount")?.integer ?? 0
                    )
                )
            }
        } else {
            return req.eventLoop.makeSucceededFuture([])
        }
    }
}

// MARK: - Reactions

extension StatisticsController {

    func getTop3ReactionsHandlerV4(req: Request) throws -> EventLoopFuture<[Reaction]> {
        guard let sqlite = req.db as? SQLiteDatabase else {
            return req.eventLoop.makeSucceededFuture([])
        }

        let query = """
            select
                replace(replace(destinationScreen, 'didViewReaction(', ''), ')', '') as reaction,
                count(*) as reactionCount,
                r.*
            from UsageMetric um
            left join Reaction r on r.title = reaction
            where destinationScreen like 'didViewReaction%'
                and destinationScreen != 'didViewReactionsTab'
                and dateTime >= date('now')
            group by reaction
            order by reactionCount desc
            limit 3
        """

        return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
            req.eventLoop.makeSucceededFuture(
                Reaction(
                    id: UUID(uuidString: row.column("id")?.string ?? ""),
                    title: row.column("title")?.string ?? "",
                    position: row.column("position")?.integer ?? 0,
                    image: row.column("image")?.string ?? "",
                    lastUpdate: row.column("lastUpdate")?.string ?? "",
                    attributionText: row.column("attributionText")?.string,
                    attributionURL: row.column("attributionURL")?.string
                )
            )
        }
    }

    func getReactionPopularityStatsHandlerV3(req: Request) throws -> EventLoopFuture<[TopChartReaction]> {
        guard let sqlite = req.db as? SQLiteDatabase else {
            return req.eventLoop.makeSucceededFuture([])
        }

        let todaysTopReaction = """
            select
                replace(replace(destinationScreen, 'didViewReaction(', ''), ')', '') as reaction,
                count(*) as reactionCount,
                r.*
            from UsageMetric um
            left join Reaction r on r.title = reaction
            where destinationScreen like 'didViewReaction%'
                and destinationScreen != 'didViewReactionsTab'
                and dateTime >= date('now')
            group by reaction
            order by reactionCount desc
            limit 1
        """

        let lastWeeksTopReaction = """
            select
                replace(replace(destinationScreen, 'didViewReaction(', ''), ')', '') as reaction,
                count(*) as reactionCount,
                r.*
            from UsageMetric um
            left join Reaction r on r.title = reaction
            where destinationScreen like 'didViewReaction%'
                and destinationScreen != 'didViewReactionsTab'
                and dateTime >= datetime('now', '-7 days')
            group by reaction
            order by reactionCount desc
            limit 1
        """

        let allTimeTopReaction = """
            select
                replace(replace(destinationScreen, 'didViewReaction(', ''), ')', '') as reaction,
                count(*) as reactionCount,
                r.*
            from UsageMetric um
            left join Reaction r on r.title = reaction
            where destinationScreen like 'didViewReaction%'
            and destinationScreen != 'didViewReactionsTab'
            group by reaction
            order by reactionCount desc
            limit 1
        """

        let todaysFuture = sqlite.query(todaysTopReaction)
        let lastWeekFuture = sqlite.query(lastWeeksTopReaction)
        let allTimeFuture = sqlite.query(allTimeTopReaction)

        return todaysFuture.and(lastWeekFuture).and(allTimeFuture).flatMap { results in
            let (todaysRows, lastWeekRows, allTimeRows) = (results.0.0, results.0.1, results.1)

            let today = todaysRows.compactMap { row in
                TopChartReaction(
                    position: "1",
                    reaction: Reaction(
                        id: UUID(uuidString: row.column("id")?.string ?? ""),
                        title: row.column("title")?.string ?? "",
                        position: row.column("position")?.integer ?? 0,
                        image: row.column("image")?.string ?? "",
                        lastUpdate: row.column("lastUpdate")?.string ?? "",
                        attributionText: row.column("attributionText")?.string,
                        attributionURL: row.column("attributionURL")?.string
                    ),
                    description: "hoje"
                )
            }

            let lastWeek = lastWeekRows.compactMap { row in
                TopChartReaction(
                    position: "2",
                    reaction: Reaction(
                        id: UUID(uuidString: row.column("id")?.string ?? ""),
                        title: row.column("title")?.string ?? "",
                        position: row.column("position")?.integer ?? 0,
                        image: row.column("image")?.string ?? "",
                        lastUpdate: row.column("lastUpdate")?.string ?? "",
                        attributionText: row.column("attributionText")?.string,
                        attributionURL: row.column("attributionURL")?.string
                    ),
                    description: "última semana"
                )
            }

            let allTime = allTimeRows.compactMap { row in
                TopChartReaction(
                    position: "3",
                    reaction: Reaction(
                        id: UUID(uuidString: row.column("id")?.string ?? ""),
                        title: row.column("title")?.string ?? "",
                        position: row.column("position")?.integer ?? 0,
                        image: row.column("image")?.string ?? "",
                        lastUpdate: row.column("lastUpdate")?.string ?? "",
                        attributionText: row.column("attributionText")?.string,
                        attributionURL: row.column("attributionURL")?.string
                    ),
                    description: "todos os tempos"
                )
            }

            return req.eventLoop.makeSucceededFuture(today + lastWeek + allTime)
        }
    }
}
