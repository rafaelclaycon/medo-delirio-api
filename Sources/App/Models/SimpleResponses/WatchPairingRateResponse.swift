//
//  WatchPairingRateResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 03/09/26.
//

import Vapor

struct WatchPairingRateResponse: Content {

    /// Activity window used to define an active user, in days.
    let activeDays: Int
    /// Distinct installs with a still-alive signal inside the window.
    let activeUsers: Int
    /// Active installs that also have a known `isWatchPaired` value. This is the
    /// denominator of `percentage` — installs without the data (iPad/Mac, or that
    /// haven't reported yet) are excluded rather than counted as "not paired".
    let eligibleUsers: Int
    /// Eligible installs with an Apple Watch paired. Numerator of `percentage`.
    let watchPairedUsers: Int
    /// `watchPairedUsers / eligibleUsers * 100`, rounded to 2 decimals. `0` when
    /// `eligibleUsers` is `0`.
    let percentage: Double
    let generatedAt: String
}
