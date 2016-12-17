//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation


class UserInputView {
    
    private let renderer = TerminalCanvas()
    
    private let terminalDevice: TerminalDevice
    
    init(_ device: TerminalDevice) {
        self.terminalDevice = device
    }
    
    var placeholder = R.string.inputPlaceholder
    
    var input = ""
    
    var cursor = 0
    
    func draw() {
        
        let size = self.terminalDevice.size
        
        guard size.width > 0 && size.height > 0 else {
            return
        }
        
        self.renderer
            .clear()
            .hideCursor()
            .cursor(R.dimen.channelsListWidth + 1, size.height - 1)
            .background(R.color.defaultBgColor)
            .color(R.color.channelListBgColor)
            .text(String(repeating: "─", count: size.width-R.dimen.channelsListWidth))
            .cursor(R.dimen.channelsListWidth + 1, size.height)
        
        if self.input.isEmpty {
            self.renderer
                .color(R.color.userInputPlaceholderTextColor)
                .background(R.color.userInputBackgorundColor)
                .text((" " + placeholder).padding(toLength: size.width - R.dimen.channelsListWidth, withPad: " ", startingAt: 0))
                .cursor(R.dimen.channelsListWidth + 2, size.height)
        } else {
            self.renderer
                .color(R.color.userInputTextColor)
                .background(R.color.userInputBackgorundColor)
                .text((" " + input).padding(toLength: size.width - R.dimen.channelsListWidth, withPad: " ", startingAt: 0))
                .cursor(R.dimen.channelsListWidth + 2 + cursor, size.height)
        }
        
        self.renderer.showCursor()
        
        self.terminalDevice.flush(renderer.buffer)
    }
}
