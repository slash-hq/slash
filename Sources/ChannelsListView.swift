//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//


import Foundation

struct ChannelListRow {
    
    let id: String
    let name: String
}

class ChannelsListView {
    
    private let canvas = TerminalCanvas()
    
    private let terminalDevice: TerminalDevice
    
    init(_ device: TerminalDevice) {
        self.terminalDevice = device
    }

    func drawRow(_ text: String, row: Int, highlight: Bool = false, blink: Bool = false) {
        
        let availableWidth = R.dimen.channelsListWidth
        
        let paddedName = text.count > availableWidth ? String(text[..<text.index(text.startIndex, offsetBy: availableWidth)]) :
            text.padding(toLength: availableWidth, withPad: " ", startingAt: 0)
        
        self.canvas
            .cursor(1, row)
            .blink(blink)
            .background(highlight ? R.color.channelListBgColorSelected : R.color.channelListBgColor)
            .text(paddedName)
    }
    
    func draw(_ context: SlackContext, selectionId: String? = nil, unreadIds: Set<String> = []) {
        
        let size = self.terminalDevice.size
        
        let avaibleHeight = size.height
        
        guard size.width > 0 && avaibleHeight > 0 else { return }
        
        var offset = 1
        
        self.canvas
            .clear()
            .hideCursor()
        
        // Draw team name.
        
        self.canvas
            .color(R.color.teamNameTextColor)
            .background(R.color.teamNameBackgroundColor)
            .cursor(1, 1)
            .text(context.teamName.padding(toLength: R.dimen.channelsListWidth, withPad: " ", startingAt: 0))
        
        offset = offset + 1
        
        // Draw channels.
        
        self.canvas.color(R.color.channelNameTextColor);
        
        for channel in context.channels {
            if (!channel.isMember) {
                continue
            }
        
            self.drawRow("#" + channel.name, row: offset, highlight: channel.id == selectionId, blink: unreadIds.contains(channel.id))
            
            offset = offset + 1
            if offset > avaibleHeight {
                break
            }
        }
        
        // Draw groups.
        
        self.canvas.color(R.color.groupNameTextColor);
        
        if offset < avaibleHeight {
            for group in context.groups {
                
                self.drawRow("#" + group.name, row: offset, highlight: group.id == selectionId, blink: unreadIds.contains(group.id))
                
                offset = offset + 1
                if offset > avaibleHeight {
                    break
                }
            }
        }
        
        // Draw members.
        
        if offset < avaibleHeight {
            for im in context.ims {
                let slackUser = context.user(forId: im.user) ?? SlackUser(id: "", name: "", color: "", presence: .away)
                if slackUser.presence == .active {
                    self.canvas.color(Utils.xterm256Color(forUser: slackUser))
                } else {
                    self.canvas.color(R.color.channelListTextColorAway)
                }
                self.drawRow("@" + (context.user(forId: im.user)?.name ?? ""), row: offset, highlight: im.id == selectionId, blink: unreadIds.contains(im.id))
                offset = offset + 1
                if offset > avaibleHeight {
                    break
                }
            }
        }
        
        self.canvas
            .color(R.color.channelNameTextColor)
            .background(R.color.channelListBgColor)
        
        while offset <= avaibleHeight {
            self.canvas
                .cursor(1, offset)
                .text(String(repeating: " ", count: R.dimen.channelsListWidth))
            offset = offset + 1
        }
        
        self.canvas.reset()
        
        terminalDevice.flush(self.canvas.buffer)
    }
}
