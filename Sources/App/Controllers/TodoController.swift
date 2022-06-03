import Fluent
import Vapor

struct TodoController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let todos = routes.grouped("todos")
        todos.get(use: index)
        todos.post(use: create)
        todos.group(":todoID") { todo in
            todo.delete(use: delete)
        }
    }

    func index(req: Request) async throws -> [ShareCountStat] {
        try await ShareCountStat.query(on: req.db).all()
    }

    func create(req: Request) async throws -> ShareCountStat {
        let todo = try req.content.decode(ShareCountStat.self)
        try await todo.save(on: req.db)
        return todo
    }

    func delete(req: Request) async throws -> HTTPStatus {
        guard let todo = try await ShareCountStat.find(req.parameters.get("todoID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await todo.delete(on: req.db)
        return .ok
    }

}
