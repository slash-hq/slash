//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation

extension URLSession {

    /// Synchonized version of dataTask(with URLRequest)
    func synchronousDataTask(with request: URLRequest) throws -> (data: Data?, response: HTTPURLResponse?) {
        
        let semaphore = DispatchSemaphore(value: 0)
        
        var data: Data?
        var response: URLResponse?
        var error: Error?
        
        URLSession.shared.dataTask(with: request) { (theData, theResponse, theError) -> Void in
            // extract information from callback
            data = theData
            response = theResponse
            error = theError
            
            // wake semaphore
            semaphore.signal()
            
            }.resume()
        
        // wait until signaled
        _ = semaphore.wait(timeout: .distantFuture)
        
        // do we have an error?
        if let error = error {
            throw error
        }
        
        return (data: data, response: response as! HTTPURLResponse?)
    }
}
