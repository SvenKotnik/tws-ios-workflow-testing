//
//  TWSView+WebViewDownloadDelegate.swift
//  TWSKit
//
//  Created by Luka Kit on 10. 9. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import Foundation
import WebKit

extension WebView.Coordinator: WKDownloadDelegate {

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let fileName = documentsURL!.appendingPathComponent(suggestedFilename)
        completionHandler(fileName)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        logger.warn("Download failed with error: \(error.localizedDescription)")
    }

    func download(_ download: WKDownload, didFinishDownloadingTo location: URL) {
        logger.info("Download finished: \(location)")
    }

    func downloadDidFinish(_ download: WKDownload) {
        logger.info("Download completed successfully.")
    }
}
