//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation

enum ControlKey {
    
    case null
    case ctrlC
    case ctrlD
    case ctrlF
    case ctrlH
    case tab(Bool)
    case cr
    case ctrlL
    case enter
    case ctrlQ
    case ctrlS
    case ctrlU
    case esc
    case backspace
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
    
    case other(UInt8)
}

class TerminalDevice {
    
    enum TerminalError: Error {
        case error(String)
    }
    
    private var originalTermios = termios()
    
    init() throws {
        guard tcgetattr(fileno(stdin), &self.originalTermios) == 0 else {
            throw TerminalError.error("Could not load current terminal config: \(errno)")
        }
        try self.terminalEnableRawMode()
        
        self.flush(TerminalCanvas().clean().buffer)
    }

    var size: (width: Int, height: Int) {
        var w = winsize()
        guard ioctl(fileno(stdout), TIOCGWINSZ, &w) == 0 else {
            exit(1)
        }
        return (Int(w.ws_col), Int(w.ws_row))
    }
    
    func key() -> ControlKey {
        
        var buffer: [UInt8] = [0, 0, 0, 0]
        
        read(fileno(stdin), &buffer, 1)
        
        switch buffer[0] {
            
            case 0: return .null
            case 3: return .ctrlC
            case 4: return .ctrlD
            case 6: return .ctrlF
            case 8: return .ctrlH
            case 9: return .tab(false)
            case 10: return .cr
            case 12: return .ctrlL
            case 13: return .enter
            case 17: return .ctrlQ
            case 19: return .ctrlS
            case 21: return .ctrlU
            
            case 27:
                
                read(fileno(stdin), &buffer, 4)
                
                if buffer[0] == 0x5B {
                    switch buffer[1] {
                        case 0x41: return .arrowUp
                        case 0x42: return .arrowDown
                        case 0x44: return .arrowLeft
                        case 0x43: return .arrowRight
                        case 0x5A: return .tab(true)
                        default: break
                    }
                }
                
                return .esc
                
            case 127: return .backspace
                
            default: return .other(buffer[0])
        }
    }
    
    func flush(_ buffer: [UInt8]) {
        write(fileno(stdout), buffer, buffer.count)
    }
    
    func reset() throws {
        guard tcsetattr(fileno(stdin), TCSAFLUSH, &self.originalTermios) == 0 else {
            throw TerminalError.error("Could not revert the original mode: \(errno)")
        }
        self.flush(TerminalCanvas().clean().cursor(1, 1).showCursor().buffer)
    }
    
    private func terminalEnableRawMode() throws {
        
        var rawModeTermios = termios()
        
        memcpy(&rawModeTermios, &self.originalTermios, MemoryLayout<termios>.size)
        
        rawModeTermios.c_lflag = UInt(Int32(rawModeTermios.c_lflag)
            
            & (~(ECHO | ECHONL | ICANON | IEXTEN | ISIG)))
        
        rawModeTermios.c_iflag = UInt(Int32(rawModeTermios.c_iflag)
            
            & (~(IGNBRK | BRKINT | INLCR | ICRNL | INPCK | PARMRK | ISTRIP | IXON | IUTF8)))
        
        rawModeTermios.c_cflag = UInt(Int32(rawModeTermios.c_cflag) & CS8)
        rawModeTermios.c_oflag = 0
        
        rawModeTermios.c_cc.17 /*[VTIME]*/ = 0
        rawModeTermios.c_cc.16 /*[VMIN] */ = 1
        
        guard tcsetattr(fileno(stdin), TCSAFLUSH, &rawModeTermios) == 0 else {
            throw TerminalError.error("Could not enable raw mode: \(errno)")
        }
    }
}
