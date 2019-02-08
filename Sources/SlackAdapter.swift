//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//


import Foundation

class SlackAdapter {
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    private let emojiDecoder = SlackEmojiDecoder()
    
    func formatSlackTimestamp(_ slackTs: String) -> String {
        if let timestamp = Double(slackTs) {
            let date = Date(timeIntervalSince1970: timestamp)
            return self.dateFormatter.string(from: date)
        } else {
            return slackTs
        }
    }
    
    func textSpansFor(message: SlackMessage, withContext context: SlackContext, andLinks links: inout [String]) -> [TextSpan] {
        
        let slackUser = context.user(forId: message.user) ?? SlackUser(id: "", name: "unknown", color: "", presence: .away)
        
        var spans = [TextSpan]()
        
        spans.append(TextSpan(self.formatSlackTimestamp(message.ts), withColor: R.color.messageTimeTextColor))
        spans.append(TextSpan(" \(slackUser.name)", withColor: Utils.xterm256Color(forUser: slackUser)))
        spans.append(TextSpan(": ", withColor: R.color.messagePrefixTextColor))
        spans.append(contentsOf: self.spansFor(message: message.text, withContext: context, andLinks: &links))
        
        if !message.reactions.isEmpty {
            let content = "\n      " + message.reactions.map({ emojiDecoder.decode( ":" + $0.name + ":" ) + reactionCounter(forCount: $0.count) } ).joined(separator: " ")
            
            spans.append(TextSpan(content, withColor: R.color.reactionTextColor, withBackground: R.color.defaultBgColor))
        }
        
        return spans
    }
    
    func reactionCounter(forCount count: Int) -> String {
        if count <= 1 {
            return ""
        }
        return String(String(describing: count).map({ c in //TODO - Do it better with 'U+2080 + x' formula.
            switch c {
            case "0": return "₀"
            case "1": return "₁"
            case "2": return "₂"
            case "3": return "₃"
            case "4": return "₄"
            case "5": return "₅"
            case "6": return "₆"
            case "7": return "₇"
            case "8": return "₈"
            case "9": return "₉"
            default : return " "
            }
        }))
    }
    
    func spansFor(message: String, withContext context: SlackContext, andLinks links: inout [String]) -> [TextSpan] {
        
        var spans = [TextSpan]()
        
        for token in self.lex(for: message) {
            switch token {
            case .plain(let text):
                let presentableText = self.emojiDecoder.decode(self.decodeEscapedHTMLEntities(text))
                spans.append(TextSpan(presentableText, withColor: R.color.messageTextColor))
            case .escaped(let encodedText):
                guard let first = encodedText.first else {
                    continue
                }
                switch first {
                    case "#":
                        fallthrough
                    case "@":
                        let idStartIndex = encodedText.index(encodedText.startIndex, offsetBy: 1)
                        if idStartIndex < encodedText.endIndex {
                            let id = encodedText[idStartIndex..<(encodedText.index(of: "|") ?? encodedText.endIndex)]
                            if let name = context.name(forId: String(id)) {
                                spans.append(TextSpan(name, withColor: R.color.mentionTextColor))
                            }
                        }
                    case "!":
                        let escapedTokens = encodedText.components(separatedBy: "|")
                        if let command = escapedTokens.first {
                            let commandName = escapedTokens.count > 1 ? escapedTokens[1] : command
                            spans.append(TextSpan(commandName, withColor: R.color.commandTextColor))
                        }
                    default /* link */:
                        let escapedTokens = encodedText.components(separatedBy: "|")
                        if let url = escapedTokens.first {
                            links.append(url)
                            if let name = escapedTokens.last, escapedTokens.count > 1 {
                                 spans.append(TextSpan(self.decodeEscapedHTMLEntities(name), withColor: R.color.linkTextColor))
                            } else {
                                 spans.append(TextSpan(url, withColor: R.color.linkTextColor))
                            }
                            spans.append(TextSpan("[" + String(links.count) + "]", withColor: R.color.messageTextColor))
                        }
                }
            }
        }
        return spans
    }
    
    enum Token { case plain(String), escaped(String) }
    
    private func lex(for message: String) -> [Token] {

        var tokens = [Token]()
        
        var buffer = [Character]()
        buffer.reserveCapacity(message.count)
        
        var plainFlag = true
        
        for (index, character) in message.enumerated() {
            switch character {
                case "<":
                    if !buffer.isEmpty {
                        tokens.append(.plain(String(buffer)))
                    }
                    buffer.removeAll(keepingCapacity: true)
                    plainFlag = false
                case ">":
                    if !buffer.isEmpty {
                        tokens.append(.escaped(String(buffer)))
                    }
                    buffer.removeAll(keepingCapacity: true)
                    plainFlag = true
                default:
                    buffer.append(character)
                    if index == message.count - 1 {
                        tokens.append(plainFlag ? .plain(String(buffer)) : .escaped(String(buffer)))
                    }
            }
        }
        
        return tokens
    }
    
    private func decodeEscapedHTMLEntities(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
