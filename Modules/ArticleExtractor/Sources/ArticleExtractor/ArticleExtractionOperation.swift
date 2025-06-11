import Foundation
import Articles
import RSWeb

public final class ArticleExtractionOperation: Operation, ArticleExtractorDelegate {
    private var extractor: ArticleExtractor?
    private let article: Article
    private let progress: DownloadProgress?
    private let saveHandler: (ExtractedArticle, String) -> Void

    private var _isExecuting = false
    private var _isFinished = false

	public override var isAsynchronous: Bool { true }
	public override private(set) var isExecuting: Bool {
        get { _isExecuting }
        set {
            willChangeValue(forKey: "isExecuting")
            _isExecuting = newValue
            didChangeValue(forKey: "isExecuting")
        }
    }
	public override private(set) var isFinished: Bool {
        get { _isFinished }
        set {
            willChangeValue(forKey: "isFinished")
            _isFinished = newValue
            didChangeValue(forKey: "isFinished")
        }
    }

    public init?(article: Article, progress: DownloadProgress? = nil, saveHandler: @escaping (ExtractedArticle, String) -> Void) {
        guard let link = article.linkForExtraction, let extractor = ArticleExtractor(link,skipParsing: true) else { return nil }
        self.article = article
        self.extractor = extractor
        self.progress = progress
        self.saveHandler = saveHandler
        super.init()
    }

	public override func start() {
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
        extractor.processText()
    }

	public override func cancel() {
        extractor?.cancel()
        super.cancel()
        finish()
    }

    private func finish() {
        if isExecuting { isExecuting = false }
        if !isFinished {
            isFinished = true
            progress?.completeTask()
        }
    }

    // MARK: ArticleExtractorDelegate
	public func articleExtractionDidFail(with: Error) {
        finish()
    }

	public func articleExtractionDidComplete(extractedArticle: ExtractedArticle) {
		saveHandler(extractedArticle, article.articleID)
		finish()
	}
}
