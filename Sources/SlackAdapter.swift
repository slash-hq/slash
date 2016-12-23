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
    
    func textSpansFor(message: SlackMessage, withContext context: SlackContext) -> [TextSpan] {
        
        let slackUser = context.user(forId: message.user) ?? SlackUser(id: "", name: "unknonw", color: "", presence: .away)
        
        var spans = [TextSpan]()
        
        spans.append(TextSpan(self.formatSlackTimestamp(message.ts), withColor: R.color.messageTimeTextColor))
        spans.append(TextSpan(" \(slackUser.name)", withColor: Utils.xterm256Color(forUser: slackUser)))
        spans.append(TextSpan(": ", withColor: R.color.messagePrefixTextColor))
        spans.append(contentsOf: self.spansFor(message: message.text, withContext: context))
        
        return spans
    }
    
    
    func spansFor(message: String, withContext context: SlackContext) -> [TextSpan] {
        
        var spans = [TextSpan]()
        
        // Process Emoji
        
        let message = self.emojiDecoder.decode(message)
        
        // Process mentions.
        
        var spanStart = message.characters.startIndex
        var spanEnd = spanStart
        
        while spanEnd < message.characters.endIndex {
            if message.characters[spanEnd] == "<" {
                if spanEnd > spanStart {
                    spans.append(TextSpan(String(message.characters[spanStart..<spanEnd]), withColor: R.color.messageTextColor))
                }
                let escapeStartIndex = message.characters.index(spanEnd, offsetBy: 1)
                var escapeEndIndex = escapeStartIndex
                while escapeEndIndex < message.characters.endIndex && message.characters[escapeEndIndex] != ">" {
                    escapeEndIndex = message.characters.index(escapeEndIndex, offsetBy: 1)
                }
                if escapeEndIndex != escapeStartIndex {
                    let escapedCharacters = message.characters[escapeStartIndex..<escapeEndIndex]
                    if escapedCharacters[escapedCharacters.startIndex] == "#" ||
                        escapedCharacters[escapedCharacters.startIndex] == "@" {
                        let idStartIndex = escapedCharacters.index(escapedCharacters.startIndex, offsetBy: 1)
                        if idStartIndex < escapedCharacters.endIndex {
                            let id = escapedCharacters[idStartIndex..<(escapedCharacters.index(of: "|") ?? escapedCharacters.endIndex)]
                            if let name = context.name(forId: String(id)) {
                                spans.append(TextSpan(name, withColor: R.color.mentionTextColor))
                            }
                        }
                    } else {
                        spans.append(TextSpan(self.escapeHTMLEntities(String(message.characters[escapeStartIndex..<escapeEndIndex])), withColor: R.color.linkTextColor))
                    }
                }
                spanStart = message.characters.index(escapeEndIndex, offsetBy: 1)
                spanEnd = spanStart
            } else {
                spanEnd = message.characters.index(spanEnd, offsetBy: 1)
            }
        }
        
        if spanEnd > spanStart {
            spans.append(TextSpan(self.escapeHTMLEntities(String(message.characters[spanStart..<spanEnd])), withColor: R.color.messageTextColor))
        }
        
        return spans
    }
    
    private func escapeHTMLEntities(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
