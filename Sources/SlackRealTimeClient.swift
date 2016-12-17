//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation


class SlackRealTimeClient {
    
    enum Err: Error {
        case error(String)
    }
    
    private let websocketClient: WebSocketClient
    
    init(_ url: String) throws {
        
        guard let wssUrl = URL(string: url) else {
            throw Err.error("Failed to create URL object from: \(url).")
        }
        
        guard let wssHost = wssUrl.host else {
            throw Err.error("Could not find host for: \(wssUrl).")
        }

        self.websocketClient = try WebSocketClient(wssHost, path: wssUrl.path)
    }
 
    func send(_ channel: String, message: String, replyId: Int) throws {
        let jsonData = try JSONSerialization.data(withJSONObject:
            ["id": replyId, "type": "message", "channel": channel, "text": message],
             options: .prettyPrinted)
        try self.websocketClient.writeFrame(opcode: .text, payload: [UInt8](jsonData))
    }
    
    func waitForEvent() throws -> SlackEvent? {
        
        guard let frame = try self.websocketClient.waitForFrame() else {
            return nil
        }
        switch frame.opcode {
        case .text:
            let object = try JSONSerialization.jsonObject(with: Data(frame.payload), options: .init(rawValue: 0))
            guard let dictionary = object as? Dictionary<String, Any> else {
                return nil
            }
            if let replyToId = dictionary["reply_to"] as? Int {
                let ts = (dictionary["ts"] as? String) ?? ""
                return .reply(replyToId, ts)
            }
            guard let type = dictionary["type"] as? String else {
                return nil
            }
            switch type {
                case "hello":
                    return .hello
                case "message":
                    return self.handleMessageEvent(dictionary)
                case "reconnect_url":
                    return .reconnectUrl
                case "user_typing":
                    let channel = (dictionary["channel"] as? String) ?? ""
                    let user = (dictionary["user"] as? String) ?? ""
                    return .userTyping(channel, user)
                case "channel_marked":
                    return .channelMarked
                case "presence_change":
                    let user = (dictionary["user"] as? String) ?? ""
                    let presenceValue: String = (dictionary["presence"] as? String) ?? ""
                    return .presenceChange(user, presenceValue == "active" ? .active : .away)
                case "file_created":
                    return .fileCreated
                case "file_public":
                    return .filePublic
                case "file_shared":
                    return .fileShared
                case "file_change":
                    return .fileChange
                case "pref_change":
                    return .prefChange
                case "group_marked":
                    return .groupMarked
                case "mpim_marked":
                    return .mpimMarked
                case "im_marked":
                    return .imMarked
                case "reaction_added":
                    return .reactionAdded
                case "user_change":
                    return .userChange
                case "team_rename":
                    let name = (dictionary["name"] as? String) ?? ""
                    return .teamRename(name)
                default:
                    return .unknown("\(type) - \(dictionary)")
            }
        case .ping:
            try self.websocketClient.writeFrame(opcode: .pong)
        default:
            return nil
        }
        return nil
    }
    
    private func handleMessageEvent(_ dictionary: Dictionary<String, Any>) -> SlackEvent {
        
        let channel = (dictionary["channel"] as? String) ?? ""
        let user    = (dictionary["user"] as? String) ?? "unknown"
        let message = (dictionary["text"] as? String) ?? ""
        let ts      = (dictionary["ts"] as? String) ?? ""
        let subType = (dictionary["subtype"] as? String) ?? ""
        
        switch subType {
            case "message_changed":
                if let updatedMessage = (dictionary["message"] as? Dictionary<String, Any>) {
                    let user = (updatedMessage["user"] as? String) ?? "unknown"
                    let ts = (updatedMessage["ts"] as? String) ?? ""
                    let text = (updatedMessage["text"] as? String) ?? ""
                    return .messageChanged(SlackMessage(ts: ts, channel: channel, user: user, text: text))
                }
            case "message_deleted":
                let ts = (dictionary["deleted_ts"] as? String) ?? ""
                return .messageDeleted(ts, channel)
            default:break
        }
        
        return .message(SlackMessage(ts: ts, channel: channel, user: user, text: message))
    }
}
