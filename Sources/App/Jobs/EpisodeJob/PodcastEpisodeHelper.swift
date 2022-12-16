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
        let postPassword = "knit-mishmash-destruct-drag"
        
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
                //let topItem = items[1]
                
                let episode = PrimitivePodcastEpisode(
                    episodeId: topItem.guid?.value ?? UUID().uuidString,
                    title: topItem.title ?? "Sem Título",
                    description: extractFirstParagraphFrom(topItem.description),
                    pubDate: topItem.pubDate?.iso8601withFractionalSeconds ?? Date().iso8601withFractionalSeconds,
                    duration: topItem.iTunes?.iTunesDuration ?? 0,
                    creationDate: Date().iso8601withFractionalSeconds,
                    sendNotification: true)
                
                let url = URL(string: "http://127.0.0.1:8080/api/v2/add-episode/\(postPassword)")!

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
