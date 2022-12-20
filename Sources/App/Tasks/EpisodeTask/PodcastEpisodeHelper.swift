//
//  EpisodeJob.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 14/12/22.
//

import Foundation
import FeedKit

class PodcastEpisodeHelper {

    static func lookForNewEpisode() {
        let parser = FeedParser(URL: URL(string: "https://www.central3.com.br/category/podcasts/medo-e-delirio/feed/podcast/")!)
        
        parser.parseAsync { result in
            switch result {
            case let .success(feed):
                guard let feed = feed.rssFeed else {
                    return print("PodcastEpisodeHelper: Not an RSS feed. \(Date().iso8601withFractionalSeconds)")
                }
                guard let items = feed.items else {
                    return print("PodcastEpisodeHelper: Empty feed. \(Date().iso8601withFractionalSeconds)")
                }
                
                guard let topItem = items.first else {
                    return print("PodcastEpisodeHelper: Unable to get top episode. \(Date().iso8601withFractionalSeconds)")
                }
                //let topItem = items[4]
                
                let episode = PrimitivePodcastEpisode(
                    episodeId: extractEpisodeId(from: topItem.guid?.value),
                    title: topItem.title ?? "Sem Título",
                    description: extractFirstParagraphFrom(topItem.description),
                    pubDate: topItem.pubDate?.iso8601withFractionalSeconds ?? Date().iso8601withFractionalSeconds,
                    duration: topItem.iTunes?.iTunesDuration ?? 0,
                    creationDate: Date().iso8601withFractionalSeconds,
                    spotifyLink: "",
                    applePodcastsLink: "",
                    pocketCastsLink: "")
                
                let url = URL(string: "http://127.0.0.1:8080/api/v2/add-episode/\(Passwords.episodePassword)/true")!

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let jsonEncoder = JSONEncoder()
                let jsonData = try? jsonEncoder.encode(episode)
                request.httpBody = jsonData

                let task = URLSession.shared.dataTask(with: request) { _, response, _ in
                    guard let httpResponse = response as? HTTPURLResponse else {
                        return print("PodcastEpisodeHelper: URLResponse is nil. \(Date().iso8601withFractionalSeconds)")
                    }
                    print("PodcastEpisodeHelper: \(httpResponse.statusCode) \(Date().iso8601withFractionalSeconds)")
                }

                task.resume()
                
            case .failure(_):
                print("PodcastEpisodeHelper: Unable to access RSS feed. \(Date().iso8601withFractionalSeconds)")
            }
        }
    }
    
    private static func extractEpisodeId(from central3EpisodeLink: String?) -> String {
        guard let episodeLink = central3EpisodeLink else { return UUID().uuidString }
        guard let preStart = episodeLink.firstIndex(of: "=") else {
            return UUID().uuidString
        }
        let start = episodeLink.index(preStart, offsetBy: 1)
        let range = start..<episodeLink.endIndex
        return String(episodeLink[range])
    }
    
    private static func extractFirstParagraphFrom(_ text: String?) -> String {
        guard let text = text else { return "" }
        guard let preStart = text.firstIndex(of: "<"), let preEnd = text.firstIndex(of: "/") else {
            return ""
        }
        let end = text.index(preEnd, offsetBy: -1)
        let start = text.index(preStart, offsetBy: 3)
        let range = start..<end
        return String(text[range])
    }

}
