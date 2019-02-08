//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//


import Foundation

enum SlackWebClientError: Error {
    case error(String)
}

class SlackWebClient {
    
    private let token: String
    
    init(authenticatedBy token: String) {
        self.token = token
    }
    
    func rtm() throws -> SlackTeam {
        return processStartRTMresponse(try self.rpc(forMethod: "rtm.start"))
    }
    
    func history(for channel: String) throws -> [SlackMessage] {
        
        var method = "channels.history"
        
        if let firstCharacter = channel.first {
            switch firstCharacter {
                //TODO - This mapping is rather naive. There should be separated methods for: groups and ims.
                case "C": method = "channels.history"
                case "G": method = "groups.history"
                case "D": method = "im.history"
                default: break
            }
        }
        
        let response = try self.rpc(forMethod: method, withParams: ["channel": channel])
        
        guard let messages = response["messages"] as? Array<Any> else {
            throw SlackWebClientError.error("No messages array in the response \(response).")
        }
        
        return messages.map { item in
            guard let dictionary = item as? Dictionary<String, Any> else {
                return SlackMessage(ts: "", channel: "", user: "", text: "", reactions: [])
            }
            return SlackMessage(ts: (dictionary["ts"] as? String) ?? "",
                channel: channel,
                user: (dictionary["user"] as? String) ?? "",
                text: (dictionary["text"] as? String) ?? "",
                reactions: (dictionary["reactions"] as? [[String: Any]])?.map({ item in
                    return SlackMessageReaction(
                        name: item["name"] as? String ?? "",
                        count: item["count"] as? Int ?? 0,
                        users: item["users"] as? [String] ?? []
                    )
                }) ?? []
            )
        }
    }
    
    private func rpc(forMethod rpcMethod: String, withParams params: [String: String] = [:]) throws -> Dictionary<String, Any> {
        
        var queryParams = [String: String]()
        
        queryParams["token"] = token
        params.forEach { queryParams[$0.key] = $0.value }
        
        let urlString = ("https://slack.com/api/\(rpcMethod)?") + queryParams.map({ $0 + "=" + $1}).joined(separator: "&")
    
        guard let url = URL(string: urlString) else {
            throw SlackWebClientError.error("Could not create URL object.")
        }
        
        let (theData, _) = try URLSession.shared.synchronousDataTask(with: URLRequest(url: url))
        guard let data = theData else {
            throw SlackWebClientError.error("Error receiving data.")
        }
        let object = try JSONSerialization.jsonObject(with:data)
        
        guard let dict = object as? Dictionary<String, Any> else {
            throw SlackWebClientError.error("\(rpcMethod)'s response is not a dictionary.")
        }
        
        guard (dict["ok"] as? Bool) == true else {
            throw SlackWebClientError.error("result not ok \(dict).")
        }
        
        return dict
    }
    
    private func processStartRTMresponse(_ object: Any) -> SlackTeam {
        
        return SlackTeam(
            selfId : object ← "self" ← "id",
            name : object ← "team" ← "name",
            users: (object ←← "users").map(
                { SlackUser(id: $0 ← "id", name: $0 ← "name", color: $0 ← "color", presence: ($0 ← "presence") == "active" ? .active : .away) }
            ),
            channels: (object ←← "channels").map({
                SlackChannel(
                    id: $0 ← "id",
                    name: $0 ← "name",
                    members: ($0 ←← "members").map({ ($0 as? String) ?? "" }),
                    topic: $0 ← "topic",
                    general: $0 ← "is_general",
                    isMember: $0 ← "is_member"
                )}
            ),
            groups: (object ←← "groups").map(
                { SlackGroup(id: $0 ← "id", name: $0 ← "name",
                    members: ($0 ←← "members").map({ ($0 as? String) ?? "" }),
                    topic: $0 ← "topic")}
            ),
            ims: (object ←← "ims").map({ SlackIM(id: $0 ← "id", user: $0 ← "user") }),
            wssUrl: object ← "url"
        )
    }
}

precedencegroup LookupSeparatorPrecedence { associativity: left }

infix operator ← : LookupSeparatorPrecedence
infix operator ←← : LookupSeparatorPrecedence

func ← (left: Any, right: String) -> [String: Any] {
    if let dict = left as? [String: Any] {
        return (dict[right] as? [String: Any]) ?? [String: Any]()
    }
    return [String: Any]()
}

func ←← (left: Any, right: String) -> [Any] {
    if let dict = left as? [String: Any] {
        return (dict[right] as? [Any]) ?? [Any]()
    }
    return [Any]()
}

func ← (left: Any, right: String) -> String? {
    if let dict = left as? [String: Any] {
        return (dict[right] as? String)
    }
    return nil
}

func ← (left: Any, right: String) -> String {
    if let dict = left as? [String: Any] {
        return (dict[right] as? String) ?? ""
    }
    return ""
}

func ← (left: Any, right: String) -> Bool? {
    if let dict = left as? [String: Any] {
        return (dict[right] as? Bool)
    }
    return nil
}

func ← (left: Any, right: String) -> Bool {
    if let dict = left as? [String: Any] {
        return (dict[right] as? Bool) ?? false
    }
    return false
}

func ← (left: [String: Any], right: String) -> [String: Any] {
    return (left[right] as? [String: Any]) ?? [String: Any]()
}

func ← (left: [String: Any], right: String) -> Int? {
    return (left[right] as? Int) ?? nil
}

func ← (left: [String: Any], right: String) -> Int {
    return (left[right] as? Int) ?? 0
}

func ← (left: [String: Any], right: String) -> String? {
    return (left[right] as? String) ?? nil
}

func ← (left: [String: Any], right: String) -> String {
    return (left[right] as? String) ?? ""
}

func ← (left: [String: Any], right: String) -> Bool? {
    return (left[right] as? Bool)
}

func ← (left: [String: Any], right: String) -> Bool {
    return (left[right] as? Bool) ?? false
}
