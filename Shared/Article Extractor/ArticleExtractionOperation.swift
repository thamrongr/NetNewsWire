import Foundation
import Articles

final class ArticleExtractionOperation: Operation, ArticleExtractorDelegate {
    private var extractor: ArticleExtractor?
    private let article: Article

    private var _isExecuting = false
    private var _isFinished = false

    override var isAsynchronous: Bool { true }
    override private(set) var isExecuting: Bool {
        get { _isExecuting }
        set {
            willChangeValue(forKey: "isExecuting")
            _isExecuting = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }
    override private(set) var isFinished: Bool {
        get { _isFinished }
        set {
            willChangeValue(forKey: "isFinished")
            _isFinished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }

    init?(article: Article) {
        guard let link = article.preferredLink, let extractor = ArticleExtractor(link) else { return nil }
        self.article = article
        self.extractor = extractor
        super.init()
    }

    override func start() {
        if isCancelled {
            finish()
            return
        }
        guard let extractor else {
            finish()
            return
        }
        isExecuting = true
        extractor.delegate = self
        extractor.process()
    }

    override func cancel() {
        extractor?.cancel()
        super.cancel()
        finish()
    }

    private func finish() {
        if isExecuting { isExecuting = false }
        if !isFinished { isFinished = true }
    }

    // MARK: ArticleExtractorDelegate
    func articleExtractionDidFail(with: Error) {
        finish()
    }

    func articleExtractionDidComplete(extractedArticle: ExtractedArticle) {
        article.account?.saveExtractedArticle(extractedArticle, articleID: article.articleID)
        finish()
    }
}
