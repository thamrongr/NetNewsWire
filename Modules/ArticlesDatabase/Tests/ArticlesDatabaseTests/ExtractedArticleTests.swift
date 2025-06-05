import XCTest
@testable import ArticlesDatabase
import Articles

final class ExtractedArticleTests: XCTestCase {
    func testEncodingDecoding() throws {
        let status = ArticleStatus(articleID: "id", read: false, starred: false, dateArrived: Date())
        let extracted = ExtractedArticle(title: "t", author: nil, datePublished: nil, dek: nil, leadImageURL: nil, content: "c", nextPageURL: nil, url: nil, domain: nil, excerpt: nil, wordCount: nil, direction: nil, totalPages: nil, renderedPages: nil)
        let article = Article(accountID: "acc", articleID: "id", webFeedID: "feed", uniqueID: "uid", title: nil, contentHTML: nil, contentText: nil, url: nil, externalURL: nil, summary: nil, imageURL: nil, datePublished: nil, dateModified: nil, authors: nil, status: status, extractedArticle: extracted)
        let dict = article.databaseDictionary()!
        let data = dict[DatabaseKey.extractedArticle] as? Data
        XCTAssertNotNil(data)
        let decoded = try JSONDecoder().decode(ExtractedArticle.self, from: data!)
        XCTAssertEqual(decoded, extracted)
    }

    func testSaveAndFetchExtractedArticle() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let accountID = "acc"
        let db = ArticlesDatabase(databaseFilePath: tempURL.path, accountID: accountID, retentionStyle: .feedBased)
        let status = ArticleStatus(articleID: "id", read: false, starred: false, dateArrived: Date())
        let article = Article(accountID: accountID, articleID: "id", webFeedID: "feed", uniqueID: "uid", title: nil, contentHTML: nil, contentText: nil, url: nil, externalURL: nil, summary: nil, imageURL: nil, datePublished: nil, dateModified: nil, authors: nil, status: status)
        db.queue.runInDatabase { result in
            let database = result.database!
            database.executeUpdate("INSERT INTO articles (articleID, feedID, uniqueID) VALUES (?,?,?);", withArgumentsIn: [article.articleID, article.webFeedID, article.uniqueID])
            database.executeUpdate("INSERT INTO statuses (articleID, read, starred, dateArrived) VALUES (?,?,?,?);", withArgumentsIn: [article.articleID, 0, 0, Date()])
        }
        let extracted = ExtractedArticle(title: "t", author: nil, datePublished: nil, dek: nil, leadImageURL: nil, content: "c", nextPageURL: nil, url: nil, domain: nil, excerpt: nil, wordCount: nil, direction: nil, totalPages: nil, renderedPages: nil)
        db.saveExtractedArticle(extracted, for: article.articleID)
        let fetched = try db.fetchArticles(articleIDs: Set([article.articleID])).first
        XCTAssertEqual(fetched?.extractedArticle, extracted)
    }
}
