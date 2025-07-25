//
//  ArticleExtractor.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import Articles
import Secrets
import SwiftSoup
import RSParser

public enum ArticleExtractorState {
    case ready
    case processing
    case failedToParse
    case complete
	case cancelled
}

public protocol ArticleExtractorDelegate {
    func articleExtractionDidFail(with: Error)
    func articleExtractionDidComplete(extractedArticle: ExtractedArticle)
}

public class ArticleExtractor {
	
	private var dataTask: URLSessionDataTask? = nil
    
	public var state: ArticleExtractorState!
	public var article: ExtractedArticle?
	public var delegate: ArticleExtractorDelegate?
	public var articleLink: String?
	
    private var url: URL!
    
    public init?(_ articleLink: String) {
		self.articleLink = articleLink
		
		let clientURL = "https://extract.feedbin.com/parser"
		let username = "" //SecretsManager.provider.mercuryClientId
		let signature = "" //articleLink.hmacUsingSHA1(key: SecretsManager.provider.mercuryClientSecret)
		
		if let base64URL = articleLink.data(using: .utf8)?.base64EncodedString() {
			let fullURL = "\(clientURL)/\(username)/\(signature)?base64_url=\(base64URL)"
			if let url = URL(string: fullURL) {
				self.url = url
				return
			}
		}
		
		return nil
    }
    
    public func process() {
        
        state = .processing

        dataTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            
            guard let self = self else { return }
            
            if let error = error {
                self.state = .failedToParse
                DispatchQueue.main.async {
                    self.delegate?.articleExtractionDidFail(with: error)
                }
                return
            }
            
            guard let data = data else {
                self.state = .failedToParse
                DispatchQueue.main.async {
					self.delegate?.articleExtractionDidFail(with: URLError(.cannotDecodeContentData))
                }
                return
            }
 
            do {
				let decoder = JSONDecoder()
				decoder.dateDecodingStrategy = .iso8601
				self.article = try decoder.decode(ExtractedArticle.self, from: data)
				
                DispatchQueue.main.async {
					if self.article?.content == nil {
						self.state = .failedToParse
						self.delegate?.articleExtractionDidFail(with: URLError(.cannotDecodeContentData))
					} else {
						self.state = .complete
						self.delegate?.articleExtractionDidComplete(extractedArticle: self.article!)
					}
				}
			} catch {
				self.state = .failedToParse
				DispatchQueue.main.async {
					self.delegate?.articleExtractionDidFail(with: error)
				}
			}
			
		}
		
		dataTask!.resume()
		
	}
	
	public init?(_ articleLink: String, skipParsing: Bool = false) {
		self.articleLink = articleLink
		if let url = URL(string: articleLink) {
			self.url = url
			return
		}
		return nil
	}
	
	public func processText() {
		
		state = .processing
		
		dataTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in

			guard let self = self else { return }
			
			if let error = error {
				self.state = .failedToParse
				DispatchQueue.main.async {
					self.delegate?.articleExtractionDidFail(with: error)
				}
				return
			}
			
			guard let data = data else {
				self.state = .failedToParse
				DispatchQueue.main.async {
					self.delegate?.articleExtractionDidFail(with: URLError(.cannotDecodeContentData))
				}
				return
			}
 
			do {
				let htmlString = String(data: data, encoding: .utf8) ?? ""
				let document = try SwiftSoup.parse(htmlString)
				let title = try document.title()
				let articleElement = try document.select("article").first()
				let body: String

				if let articleText = try articleElement?.text(), !articleText.isEmpty {
					body = articleText
				} else if let bodyText = try document.body()?.text() {
					body = bodyText
				} else {
					body = ""
				}
				_ = ParsedFeed(
					type: .rss,
					title: "",
					homePageURL: nil,
					feedURL: self.url?.absoluteString,
					language: nil,
					feedDescription: nil,
					nextURL: nil,
					iconURL: nil,
					faviconURL: nil,
					authors: nil,
					expired: false,
					hubs: nil,
					items: []
				)
				let extracted = ExtractedArticle(title: title, author: nil, datePublished: nil, dek: nil, leadImageURL: nil, content: body, nextPageURL: nil, url: self.url?.absoluteString, domain: nil, excerpt: nil, wordCount: nil, direction: nil, totalPages: nil, renderedPages: nil)
				DispatchQueue.main.async {
					self.article = extracted
					if self.article?.content?.isEmpty ?? true {
						self.state = .failedToParse
						self.delegate?.articleExtractionDidFail(with: URLError(.cannotDecodeContentData))
					} else {
						self.state = .complete
						self.delegate?.articleExtractionDidComplete(extractedArticle: extracted)
					}
				}
			} catch {
				self.state = .failedToParse
				DispatchQueue.main.async {
					self.delegate?.articleExtractionDidFail(with: error)
				}
			}
			
		}
		
		dataTask!.resume()
		
	}
	
	public func cancel() {
		state = .cancelled
		dataTask?.cancel()
	}
	
}
