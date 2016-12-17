//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation

class TerminalCanvas {
    
    var buffer = [UInt8]()
    
    init() {
        self.buffer.reserveCapacity(4_000)
    }
    
    @discardableResult func clear() -> TerminalCanvas {
        self.buffer.removeAll(keepingCapacity: true)
        return self
    }
    
    @discardableResult func cursor(_ x: Int, _ y: Int) -> TerminalCanvas {
        self.buffer.append(contentsOf: "\u{001B}[\(y);\(x)H".utf8)
        return self
    }
    
    @discardableResult func hideCursor() -> TerminalCanvas {
        self.buffer.append(contentsOf: "\u{001B}[?25l".utf8)
        return self
    }
    
    @discardableResult func showCursor() -> TerminalCanvas {
        self.buffer.append(contentsOf: "\u{001B}[?25h".utf8)
        return self
    }
    
    @discardableResult func clean() -> TerminalCanvas {
        buffer.append(contentsOf: "\u{001B}[0m\u{001B}[2J".utf8)
        return self
    }
    
    @discardableResult func color(_ color: Int) -> TerminalCanvas {
        if color < 0 {
            buffer.append(contentsOf: "\u{001B}[39m".utf8)
        } else {
            buffer.append(contentsOf: "\u{001B}[38;5;\(color)m".utf8)
        }
        return self
    }

    @discardableResult func background(_ color: Int) -> TerminalCanvas {
        if color < 0 {
            buffer.append(contentsOf: "\u{001B}[49m".utf8)
        } else {
            buffer.append(contentsOf: "\u{001B}[48;5;\(color)m".utf8)
        }
        return self
    }
    
    @discardableResult func blink(_ flag: Bool) -> TerminalCanvas {
        self.buffer.append(contentsOf: "\u{001B}[\(flag ? "5" : "25")m".utf8)
        return self
    }
    
    @discardableResult func text(_ text: String) -> TerminalCanvas {
        buffer.append(contentsOf: text.utf8)
        return self
    }
    
    @discardableResult func reset() -> TerminalCanvas {
        buffer.append(contentsOf: "\u{001B}[0m".utf8)
        return self
    }
}
