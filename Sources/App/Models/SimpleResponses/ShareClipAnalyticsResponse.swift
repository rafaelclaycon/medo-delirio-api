//
//  ShareClipAnalyticsResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 02/08/26.
//

import Vapor

struct ShareClipAnalyticsResponse: Content {

    let dailySharesLast30Days: [DailyActiveUsersResponse]
    let tapCount: Int
    let sharedCount: Int
    let sharedWithTranscriptCount: Int
    let sharedWithoutTranscriptCount: Int
    let generationFailedCount: Int
    let supportPromptShownCount: Int
    let whatsNewDismissedCount: Int
    let conversionRate: Double
}
