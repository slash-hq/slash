//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation

enum SlackOAuth2Error: Error {
    case error(String)
}

class SlackOAuth2 {
    
    static let port = 7777
    static let address = "http://localhost:\(SlackOAuth2.port)"
    
    private let clientId : String
    private let clientSecret : String
    private let permissions : [String]
    
    private var accessToken : String?
    
    init(clientId: String, clientSecret: String, permissions: [String]) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.permissions = permissions
    }
    
    func authenticate() throws -> String? {
        
        let permissionsStr = self.permissions.joined(separator: " ")
        
        Utils.shell("open", "https://slack.com/oauth/authorize?client_id=\(self.clientId)&scope=\(permissionsStr)&redirect_uri=\(SlackOAuth2.address)")
        
        let server = try Server(in_port_t(SlackOAuth2.port))
        
        var processIncomingRequests = true

        while processIncomingRequests {
            
            try server.serve { (request, responder) in
                
                guard request.path == "/" else {
                    responder(TextResponse(200, "Invalid request."))
                    return
                }
                
                guard let code = request.query.first?.1 else {
                    responder(TextResponse(200, "Could not get the code."))
                    return
                }
                
                guard let url = URL(string: "https://slack.com/api/oauth.access?client_id=\(self.clientId)&client_secret=\(self.clientSecret)&code=\(code)&redirect_uri=\(SlackOAuth2.address)") else {
                    responder(TextResponse(200, "Could not create URL object."))
                    return
                }
                
                do {
                    
                    let (theData, _) = try URLSession.shared.synchronousDataTask(with: URLRequest(url: url))
                    guard let data = theData else {
                        responder(TextResponse(200, "No response from Slack."))
                        return
                    }
                    let object = try JSONSerialization.jsonObject(with:data)
                    
                    guard let dict = object as? Dictionary<String, Any> else {
                        responder(TextResponse(200, "Slack's response is not a dictionary \(object)."))
                        return
                    }
                    
                    guard let accessToken = dict["access_token"] as? String else {
                        responder(TextResponse(200, "Could not find access token in the response \(dict)."))
                        return
                    }
                    
                    self.accessToken = accessToken
                    processIncomingRequests = false
                    
                    responder(HtmlResponse(200, R.string.authConfirmation))
                } catch {
                    responder(TextResponse(200, "Error occured for token request \(error)."))
                }
            }
        }
        

        return self.accessToken
    }
}
