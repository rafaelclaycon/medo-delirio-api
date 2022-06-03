import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return "Shantay you stay! medo-delirio-api is up and running."
    }

    app.get("hello", ":name") { req -> String in
        guard let name = req.parameters.get("name") else {
            throw Abort(.internalServerError)
        }
        return "Hello, \(name)!"
    }

    try app.register(collection: TodoController())
}
