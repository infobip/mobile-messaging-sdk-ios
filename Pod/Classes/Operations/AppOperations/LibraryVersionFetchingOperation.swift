//
// Created by Goran Tomasic on 05/10/2016.
//

import Foundation

class LibraryVersionFetchingOperation: Operation {
    var finishBlock: (MMLibraryVersionResult -> Void)?
    var remoteAPIQueue: MMRemoteAPIQueue
    var result = MMLibraryVersionResult.Cancel

    init(remoteAPIQueue: MMRemoteAPIQueue, finishBlock: (MMLibraryVersionResult -> Void)? = nil ) {
        self.remoteAPIQueue = remoteAPIQueue
        self.finishBlock = finishBlock
    }

    override func execute() {
        let request = MMGetLibraryVersionRequest()
        self.remoteAPIQueue.perform(request: request) { result in
            self.result = result
            self.finishWithError(result.error)
        }
    }

    override func finished(errors: [NSError]) {
        if let error = errors.first {
            result = MMLibraryVersionResult.Failure(error)
        }
        finishBlock?(result)
    }
}
