//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation

struct MessagesListRow {
    
    let channel: String?
    let id: String?
    let spans: [TextSpan]
    let pending: Bool
    
    init(channel: String? = nil, id: String? = nil, spans: [TextSpan], pending: Bool = false) {
        self.channel = channel
        self.id = id
        self.spans = spans
        self.pending = pending
    }
}

class MessagesListView {
    
    private let canvas = TerminalCanvas()
    private let textLayout = TextLayout()
    
    private let terminalDevice: TerminalDevice
    
    init(_ device: TerminalDevice) {
        self.terminalDevice = device
    }
    
    var scroll = 0
    
    func draw(_ rows: Array<MessagesListRow>) {
        
        let size = self.terminalDevice.size
        let bottomPadding = 2
        
        guard size.width > 0 && size.height > bottomPadding else {
            return
        }
        
        let avaibleHeight = size.height - bottomPadding
        
        self.canvas
            .clear()
            .hideCursor()
        
        let column = R.dimen.channelsListWidth + 2
        
        var rayOffset = avaibleHeight
        var scrollOffset = self.scroll
        
        // Draw from the bottom to the top.
        
        lines: for row in rows {
            
            let lines = self.textLayout.layout(row.spans, alignToWidth: size.width - column - 1)
            
            for line in lines.reversed() {
                
                if scrollOffset > 0 {
                    scrollOffset = scrollOffset - 1
                    continue
                }
                
                self.canvas
                    .cursor(column-1, rayOffset)
                    .background(R.color.messagesListBgColor)
                    .text(" ")
                    .buffer.append(contentsOf: line)
                
                rayOffset = rayOffset - 1
                if rayOffset < 1 {
                    break lines
                }
            }
        }
        
        // Clear the top if needed.
    
        if rayOffset > 0 {
            for i in 1...rayOffset {
                self.canvas
                    .cursor(R.dimen.channelsListWidth + 1, i)
                    .color(R.color.defaulTextColor)
                    .background(R.color.messagesListBgColor)
                    .text(String(repeating: " ", count: size.width - R.dimen.channelsListWidth))
            }
        }
        
        self.canvas.reset()
        
        terminalDevice.flush(self.canvas.buffer)
    }
}
