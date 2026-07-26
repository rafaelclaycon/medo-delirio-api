//
//  UpdateEventPushMiddleware.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 26/07/26.
//

import Fluent
import Vapor

/// Schedules a silent content-update push whenever an `UpdateEvent` becomes
/// visible to clients — on creation (metadata/file updates, deletions) or when
/// hidden events are flipped visible (the final step of publishing new content).
struct UpdateEventPushMiddleware: AsyncModelMiddleware {

    let app: Application

    func create(model: UpdateEvent, on db: Database, next: AnyAsyncModelResponder) async throws {
        try await next.create(model, on: db)
        if model.visible {
            await ContentUpdatePushService.shared.contentPublished(on: app)
        }
    }

    func update(model: UpdateEvent, on db: Database, next: AnyAsyncModelResponder) async throws {
        try await next.update(model, on: db)
        if model.visible {
            await ContentUpdatePushService.shared.contentPublished(on: app)
        }
    }
}
