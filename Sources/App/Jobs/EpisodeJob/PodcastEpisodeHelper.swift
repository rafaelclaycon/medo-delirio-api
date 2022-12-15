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
                    return print("Not an RSS feed")
                }
                guard let items = feed.items else {
                    return print("Empty feed")
                }
                
                guard let topItem = items.first else {
                    return print("Unable to get top episode")
                }
                //let topItem = items[1]
                
                let episode = PrimitivePodcastEpisode(
                    episodeId: topItem.guid?.value ?? UUID().uuidString,
                    title: topItem.title ?? "Sem Título",
                    description: extractFirstParagraphFrom(topItem.description),
                    pubDate: topItem.pubDate?.iso8601withFractionalSeconds ?? Date().iso8601withFractionalSeconds,
                    duration: topItem.iTunes?.iTunesDuration ?? 0)
                
                let url = URL(string: "http://127.0.0.1:8080/api/v2/add-episode")!

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let jsonEncoder = JSONEncoder()
                let jsonData = try? jsonEncoder.encode(episode)
                request.httpBody = jsonData

                let task = URLSession.shared.dataTask(with: request) { _, response, _ in
                    guard let httpResponse = response as? HTTPURLResponse else {
                        return print("URLResponse is nil")
                    }
                    print(httpResponse.statusCode)
                }

                task.resume()
                
            case .failure(_):
                print("unableToAccessRSSFeed")
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
