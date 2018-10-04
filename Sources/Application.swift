//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation

class Application {
    private let terminalDevice                  : TerminalDevice
    private let messagesListView                : MessagesListView
    private let userInputView                   : UserInputView
    private let channelsListView                : ChannelsListView
    private let webClient                       : SlackWebClient
    private let context                         : SlackContext
    private let rtmClient                       : SlackRealTimeClient
    
    private var messages                        = Array<MessagesListRow>()
    private var links                           = [String]()
    private var selectedChannel: String?        = nil
    private var replyIdCounter                  = 0
    private var unreadChannelsIds               = Set<String>()
    private let adapter                         = SlackAdapter()

    init(usingDevice device: TerminalDevice, authenticatedBy token: String) throws {
        
        self.terminalDevice = device
        
        self.messagesListView = MessagesListView(self.terminalDevice)
        self.channelsListView = ChannelsListView(self.terminalDevice)
        self.userInputView = UserInputView(self.terminalDevice)
        
        self.webClient = SlackWebClient(authenticatedBy: token)
        
        self.terminalDevice.flush(
            TerminalCanvas()
                .hideCursor()
                .color(R.color.connectingTextColor)
                .cursor(1, 1)
                .text(R.string.connecting).buffer)
        
        let team = try self.webClient.rtm()
        
        self.rtmClient = try SlackRealTimeClient(team.wssUrl)
        self.context = SlackContext(withTeam: team)
        
        if let defaultChannel = self.context.defaultChannel {
            self.selectedChannel = defaultChannel
            let defaultChannelName = self.context.name(forId: defaultChannel) ?? ""
            self.userInputView.placeholder = String(format: R.string.inputPlaceholder, defaultChannelName)
            self.userInputView.draw()
            self.reloadChannel(defaultChannel, clearChat: false)
        }
        
        DispatchQueue.global(qos: .background).async { [unowned self] in
            while true {
                do {
                    while true {
                        if let event = try self.rtmClient.waitForEvent() {
                            self.handleRealTimeSessionEvent(event)
                        }
                    }
                } catch {
                    self.appendRow(MessagesListRow(spans: [TextSpan(String(format: R.string.connectionError, "\(error)"))]))
                }
            }
        }
    }
    
    func handleRealTimeSessionEvent(_ event: SlackEvent) {
        
        switch event {
            
        case .hello:
            
            self.appendRow(MessagesListRow(spans: [TextSpan(String(format: R.string.hello, self.context.teamName), withColor: R.color.helloTextColor)]))
            
        case .reply(let replyId, let ts):
            
            if let index = self.messages.index(where: { $0.id == "pending\(replyId)" }) {
                let old = self.messages.remove(at: index)
                var newSpans = [TextSpan]()
                newSpans.append(TextSpan(adapter.formatSlackTimestamp("\(Date().timeIntervalSince1970)") + " ", withColor: R.color.messageTimeTextColor))
                newSpans.append(contentsOf: old.spans)
                self.messages.insert(MessagesListRow(channel: old.channel, id: ts, spans: newSpans), at: index)
                self.messagesListView.draw(self.messages)
            }
            
        case .message(let message):
            
            if let selectedChannel = self.selectedChannel {
                if message.channel == selectedChannel {
                    self.appendRow(self.messageListRowFor(message: message))
                } else {
                    self.unreadChannelsIds.insert(message.channel)
                    self.channelsListView.draw(self.context, selectionId: self.selectedChannel, unreadIds: self.unreadChannelsIds)
                }
            }
            
        case .messageChanged(let message):
            
            if let index = self.messages.index(where: { $0.id == message.ts && $0.channel == message.channel }) {
                self.messages[index] = self.messageListRowFor(message: message)
                self.messagesListView.draw(messages)
            }
            
        case .messageDeleted(let ts, let channel):
            
            if let index = self.messages.index(where: { $0.id == ts && $0.channel == channel }) {
                self.messages.remove(at: index)
                self.messagesListView.draw(self.messages)
            }
            
        case .presenceChange(let user, let presence):

            if let index = self.context.users.index(where: { $0.id == user }) {
                let old = self.context.users.remove(at: index)
                self.context.users.insert(SlackUser(id: old.id, name: old.name, color: old.color, presence: presence), at: index)
                self.channelsListView.draw(self.context, selectionId: self.selectedChannel, unreadIds: self.unreadChannelsIds)
            }
            
        case .teamRename(let newName):
            
            self.context.teamName = newName
            
            self.channelsListView.draw(self.context, selectionId: self.selectedChannel, unreadIds: self.unreadChannelsIds)
            
        case .desktopNotification(let title, let message):

            #if os(Linux)
                // Linux notifications not implemented yet
            #else
                Process.launchedProcess(launchPath: "/usr/bin/osascript", arguments: ["-e", "display notification \"\(message)\" with title \"slash: \(title)\""])
            #endif
            return

        case .unknown(let message):
            
            return self.appendRow(MessagesListRow(spans: ["?", " : ", TextSpan(message)]))
            
        default:
            
            break
        }
    }
    
    func notifyTerminalSizeHasChanged() {
        self.messagesListView.draw(self.messages)
        self.channelsListView.draw(self.context, selectionId: self.selectedChannel)
        self.userInputView.draw()
    }
    
    private func messageListRowFor(message: SlackMessage) -> MessagesListRow {
        let spans = self.adapter.textSpansFor(message: message, withContext: self.context, andLinks: &self.links)
        return MessagesListRow(channel: message.channel, id: message.ts, spans: spans)
    }
    
    func appendRow(_ row: MessagesListRow) {
        self.messages.insert(row, at: 0)
        self.messagesListView.draw(messages)
    }

    func reloadChannel(_ channelId: String, clearChat: Bool = true) {
        let loadingRow = MessagesListRow(spans: [TextSpan(R.string.loading, withColor: R.color.loadingTextColor)])
        if clearChat {
            self.messagesListView.draw([loadingRow])
        } else {
            self.messages.append(loadingRow)
            self.messagesListView.draw(self.messages)
        }
        DispatchQueue.global(qos: .background).async { [unowned self] in
            do {
                let rows = try self.webClient.history(for: channelId).map {
                    self.messageListRowFor(message: $0)
                }
                //TODO notify about the results in a common queue for all the background tasks.
                self.messages.removeAll(keepingCapacity: true)
                self.messages.append(contentsOf: rows)
                self.messagesListView.draw(self.messages)
                self.channelsListView.draw(self.context, selectionId: self.selectedChannel, unreadIds: self.unreadChannelsIds)
                self.userInputView.draw()
            } catch {
                //TODO handle error case.
            }
        }
    }
    
    func run() {
        
        self.messagesListView.draw(self.messages)
        
        while true {
            
            let key = self.terminalDevice.key()
        
            switch key {
                
            case .ctrlC:
                
                try? self.terminalDevice.reset()
                exit(1)
                
            case .enter:
                
                guard !self.userInputView.input.isEmpty, let targetChannel = self.selectedChannel, let me = self.context.me else {
                    continue
                }

                let message = self.userInputView.input
                
                if !self.executeLocalCommand(message) {
                    try? self.rtmClient.send(targetChannel, message: message, replyId: replyIdCounter)
                    
                    let pendingMessage = MessagesListRow(channel: targetChannel, id: "pending\(replyIdCounter)", spans: [
                        TextSpan(me.name, withColor: Utils.xterm256Color(forUser: me)),
                        TextSpan(": ", withColor: R.color.messagePrefixTextColor),
                        TextSpan(message, withColor: R.color.messageTextColor)], pending: true)
                    
                    self.messages.insert(pendingMessage, at: 0)
                    
                    self.replyIdCounter = self.replyIdCounter + 1
                    
                    self.messagesListView.draw(self.messages)
                }
                                
                self.userInputView.input = ""
                self.userInputView.cursor = 0
                self.userInputView.draw()

            case .backspace:
                
                if self.userInputView.input.isEmpty || self.userInputView.cursor <= 0 {
                    continue
                }
                self.userInputView.input.remove(at:
                    userInputView.input.index(self.userInputView.input.startIndex, offsetBy: self.userInputView.cursor-1))
                self.userInputView.cursor = max(0, self.userInputView.cursor - 1)
                self.userInputView.draw()
                
            case .arrowLeft:
                
                self.userInputView.cursor = max(0, userInputView.cursor - 1)
                self.userInputView.draw()
                
            case .arrowRight:
                
                self.userInputView.cursor = min(userInputView.input.count, userInputView.cursor + 1)
                self.userInputView.draw()
                
            case .arrowUp:
                
                self.messagesListView.scroll = self.messagesListView.scroll + 1
                self.messagesListView.draw(self.messages)
                
            case .arrowDown:
                
                guard self.messagesListView.scroll > 0 else {
                    break
                }
                
                self.messagesListView.scroll = self.messagesListView.scroll - 1
                self.messagesListView.draw(self.messages)
    
            case .tab(let withShift):
            
                guard let suggestion = self.context.suggestRecipient(for: self.selectedChannel, unreadIds: self.unreadChannelsIds, backwardSearch: withShift) else {
                    continue
                }
                
                self.userInputView.input = ""
                self.userInputView.cursor = 0
                self.messagesListView.scroll = 0
                
                self.unreadChannelsIds.remove(suggestion.id)
                
                self.selectedChannel = suggestion.id
                self.userInputView.placeholder = String(format: R.string.inputPlaceholder, suggestion.name)
                self.channelsListView.draw(self.context, selectionId: suggestion.id, unreadIds: self.unreadChannelsIds)
            
                self.reloadChannel(suggestion.id)
                self.links.removeAll()
                self.userInputView.draw()
                
            case .other(let character):
                
                self.userInputView.input.insert(Character(UnicodeScalar(character)),
                    at: self.userInputView.input.index(self.userInputView.input.startIndex,
                       offsetBy: self.userInputView.cursor))
                
                self.userInputView.cursor = userInputView.cursor + 1
                self.userInputView.draw()

            default: break
                
            }
        }
    }
    
    /// Execute a local "slash" command.
    ///
    /// The currently supported list of local commands are;
    ///
    /// - /openurl {space separated list of numbers}: opens numbered link in default browser
    ///
    func executeLocalCommand(_ command: String) -> Bool {
        if (command.hasPrefix("/openurl")) {
            let pieces = command.components(separatedBy: [",", " "])
            let linkNumbers = pieces.compactMap { Int($0) }
            for linkNumber in linkNumbers {
                let url = self.links[linkNumber - 1]
                Utils.shell("open", url)
            }
            return true
        }
        
        return false
    }
}
