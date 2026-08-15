//
//  ChaptersUsageAnalyticsResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 15/08/26.
//

import Vapor

struct ChaptersUsageAnalyticsResponse: Content {

    let dailyChapterTapsLast30Days: [DailyChapterTapsResponse]
    let tapCountEpisodeDetail: Int
    let tapCountNowPlaying: Int
    let previousCount: Int
    let nextCount: Int
    let loadedCount: Int
    let loadFailedCount: Int
    let loadFailedFileMissingCount: Int
    let loadFailedDecodeFailedCount: Int
    let loadFailedNoEntryCount: Int
    let loadFailedEmptyListCount: Int
    let hiddenCount: Int
    let issueReportedCount: Int
    let topChapters: [TopChapterItem]
}

struct DailyChapterTapsResponse: Content {

    let date: String
    let tapCount: Int
}

struct TopChapterItem: Content {

    let id: Int
    let title: String
    let tapCount: Int
}
