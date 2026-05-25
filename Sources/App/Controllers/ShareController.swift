//
//  ShareController.swift
//  medo-delirio-api
//

import Vapor
import Fluent

struct ShareController {

    // MARK: - Reaction

    func getReactionPageHandler(req: Request) async throws -> Response {
        guard
            let rawId = req.parameters.get("id"),
            let reactionId = UUID(uuidString: rawId)
        else {
            throw Abort(.badRequest)
        }

        guard let reaction = try await Reaction.query(on: req.db)
            .filter(\.$id == reactionId)
            .first()
        else {
            throw Abort(.notFound)
        }

        let soundCount = try await ReactionSound.query(on: req.db)
            .filter(\.$reactionId == reactionId.uuidString)
            .count()

        let html = reactionHTML(reaction: reaction, soundCount: soundCount)

        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/html; charset=utf-8")
        return Response(status: .ok, headers: headers, body: .init(string: html))
    }

    // MARK: - HTML

    private func reactionHTML(reaction: Reaction, soundCount: Int) -> String {
        let id = reaction.id?.uuidString ?? ""
        let title = reaction.title.capitalized
        let imageURL = reaction.image
        let soundLabel = soundCount == 1 ? "1 som" : "\(soundCount) sons"
        let appDownloadURL = ReleaseConfigs.UniversalLinks.appDownloadURL
        let attributionHTML = reaction.attributionText.map { text in
            "<p class=\"attribution\">Imagem: \(text)</p>"
        } ?? ""

        return """
        <!DOCTYPE html>
        <html lang="pt-BR">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(title) · Medo e Delírio</title>

            <meta property="og:site_name" content="Medo e Delírio" />
            <meta property="og:title" content="\(title)" />
            <meta property="og:description" content="\(soundLabel) nesta reação" />
            <meta property="og:image" content="\(imageURL)" />
            <meta property="og:url" content="https://medodelirioios.com/reaction/\(id)" />
            <meta property="og:type" content="website" />
            <meta name="twitter:card" content="summary_large_image" />
            <meta name="twitter:title" content="\(title)" />
            <meta name="twitter:description" content="\(soundLabel) nesta reação" />
            <meta name="twitter:image" content="\(imageURL)" />

            <style>
                *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
                    background-color: #0a2416;
                    color: #fff;
                    min-height: 100dvh;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    gap: 24px;
                    padding: 40px 16px;
                }

                .branding img {
                    width: 100px;
                    height: 100px;
                    border-radius: 22px;
                }

                .card {
                    width: 100%;
                    max-width: 440px;
                    background: #1c1c1e;
                    border-radius: 20px;
                    overflow: hidden;
                }

                .card-image {
                    width: 100%;
                    aspect-ratio: 16 / 9;
                    object-fit: cover;
                    display: block;
                    background-color: #2c2c2e;
                }

                .card-body {
                    padding: 24px;
                }

                .badge {
                    display: inline-block;
                    font-size: 11px;
                    font-weight: 700;
                    letter-spacing: 0.08em;
                    text-transform: uppercase;
                    color: #636366;
                    margin-bottom: 10px;
                }

                .title {
                    font-size: 30px;
                    font-weight: 800;
                    line-height: 1.15;
                    margin-bottom: 6px;
                }

                .meta {
                    font-size: 15px;
                    color: #8e8e93;
                    margin-bottom: 28px;
                }

                .cta {
                    display: block;
                    background: #0a84ff;
                    color: #fff;
                    text-decoration: none;
                    padding: 16px;
                    border-radius: 14px;
                    font-size: 17px;
                    font-weight: 600;
                    text-align: center;
                    transition: opacity 0.15s;
                }

                .cta:active { opacity: 0.8; }

                .attribution {
                    font-size: 11px;
                    color: #48484a;
                    text-align: center;
                    margin-top: 16px;
                    line-height: 1.4;
                }
            </style>
        </head>
        <body>
            <div class="branding">
                <img src="/images/webpage_logo.png" alt="Medo e Delírio">
            </div>
            <div class="card">
                <img class="card-image" src="\(imageURL)" alt="\(title)">
                <div class="card-body">
                    <span class="badge">Reação</span>
                    <h1 class="title">\(title)</h1>
                    <p class="meta">\(soundLabel)</p>
                    <a class="cta" href="\(appDownloadURL)">Abrir no Medo e Delírio iOS</a>
                    \(attributionHTML)
                </div>
            </div>
        </body>
        </html>
        """
    }
}
