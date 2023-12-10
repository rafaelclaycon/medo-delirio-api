//
//  StatisticsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor
import SQLiteNIO

struct StatisticsController {
    
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
