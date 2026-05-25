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

    // MARK: - Episode

    func getEpisodePageHandler(req: Request) async throws -> Response {
        guard let episodeId = req.parameters.get("id") else {
            throw Abort(.badRequest)
        }

        guard let episode = try await Episode.find(episodeId, on: req.db) else {
            throw Abort(.notFound)
        }

        let html = episodeHTML(episode: episode)

        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/html; charset=utf-8")
        return Response(status: .ok, headers: headers, body: .init(string: html))
    }

    // MARK: - Shared CSS

    /// Shared styles for all share pages.
    /// `titleFontSize`: pass a smaller value for longer titles (e.g. episodes).
    private func sharedCSS(titleFontSize: String = "30px") -> String {
        """
        <style>
            *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

            @keyframes flow {
                0%   { background-position: 0% 50%; }
                50%  { background-position: 100% 50%; }
                100% { background-position: 0% 50%; }
            }

            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
                min-height: 100dvh;
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                gap: 24px;
                padding: 40px 16px;
                color: #fff;

                background: linear-gradient(
                    -45deg,
                    #0d2e12,
                    #1a5c28,
                    #3d7a14,
                    #7a9010,
                    #c89010,
                    #e8c020,
                    #c89010,
                    #3d7a14,
                    #0d2e12
                );
                background-size: 400% 400%;
                animation: flow 14s ease infinite;
            }

            /* Grain noise overlay — fixed so it covers the whole viewport
               and sits below all content via z-index. */
            body::before {
                content: '';
                position: fixed;
                inset: 0;
                background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.75' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
                opacity: 0.08;
                pointer-events: none;
                z-index: 0;
            }

            .branding, .card { position: relative; z-index: 1; }

            .branding img {
                width: 100px;
                height: 100px;
                border-radius: 22px;
            }

            .card {
                width: 100%;
                max-width: 440px;
                background: rgba(8, 8, 8, 0.72);
                backdrop-filter: blur(24px);
                -webkit-backdrop-filter: blur(24px);
                border: 1px solid rgba(255, 255, 255, 0.08);
                border-radius: 20px;
                overflow: hidden;
                box-shadow: 0 8px 40px rgba(0, 0, 0, 0.45);
            }

            .card-image {
                width: 100%;
                aspect-ratio: 16 / 9;
                object-fit: cover;
                display: block;
                background-color: #111;
            }

            .card-body { padding: 24px; }

            .badge {
                display: inline-block;
                font-size: 11px;
                font-weight: 700;
                letter-spacing: 0.08em;
                text-transform: uppercase;
                color: rgba(255, 255, 255, 0.35);
                margin-bottom: 10px;
            }

            .title {
                font-size: \(titleFontSize);
                font-weight: 800;
                line-height: 1.15;
                margin-bottom: 6px;
            }

            .meta {
                font-size: 15px;
                color: rgba(255, 255, 255, 0.45);
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
                color: rgba(255, 255, 255, 0.2);
                text-align: center;
                margin-top: 16px;
                line-height: 1.4;
            }
        </style>
        """
    }

    // MARK: - HTML

    private func reactionHTML(reaction: Reaction, soundCount: Int) -> String {
        let id = reaction.id?.uuidString ?? ""
        let title = reaction.title.capitalized
        let imageURL = reaction.image
        let soundLabel = soundCount == 1 ? "1 som" : "\(soundCount) sons"
        let appDownloadURL = ReleaseConfigs.UniversalLinks.appDownloadURL
        let baseURL = ReleaseConfigs.UniversalLinks.serverBaseURL
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
            <meta property="og:url" content="\(baseURL)/reaction/\(id)" />
            <meta property="og:type" content="website" />
            <meta name="twitter:card" content="summary_large_image" />
            <meta name="twitter:title" content="\(title)" />
            <meta name="twitter:description" content="\(soundLabel) nesta reação" />
            <meta name="twitter:image" content="\(imageURL)" />

            \(sharedCSS(titleFontSize: "30px"))
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

    private func episodeHTML(episode: Episode) -> String {
        let id = episode.id ?? ""
        let title = episode.title
        let appDownloadURL = ReleaseConfigs.UniversalLinks.appDownloadURL
        let baseURL = ReleaseConfigs.UniversalLinks.serverBaseURL

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "pt_BR")
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        let formattedDate = episode.pubDate.map { dateFormatter.string(from: $0) } ?? ""

        let imageTag = episode.imageURL.map { url in
            "<img class=\"card-image\" src=\"\(url)\" alt=\"\(title)\">"
        } ?? ""

        let dateHTML = formattedDate.isEmpty ? "" : "<p class=\"meta\">\(formattedDate)</p>"

        let ogImage = episode.imageURL.map {
            """
            <meta property="og:image" content="\($0)" />
            <meta name="twitter:image" content="\($0)" />
            """
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
            <meta property="og:description" content="Ouça este episódio no app Medo e Delírio iOS" />
            <meta property="og:url" content="\(baseURL)/episode/\(id)" />
            <meta property="og:type" content="website" />
            \(ogImage)
            <meta name="twitter:card" content="summary_large_image" />
            <meta name="twitter:title" content="\(title)" />
            <meta name="twitter:description" content="Ouça este episódio no app Medo e Delírio iOS" />

            \(sharedCSS(titleFontSize: "22px"))
        </head>
        <body>
            <div class="branding">
                <img src="/images/webpage_logo.png" alt="Medo e Delírio">
            </div>
            <div class="card">
                \(imageTag)
                <div class="card-body">
                    <span class="badge">Episódio</span>
                    <h1 class="title">\(title)</h1>
                    \(dateHTML)
                    <a class="cta" href="\(appDownloadURL)">Abrir no Medo e Delírio iOS</a>
                </div>
            </div>
        </body>
        </html>
        """
    }
}
