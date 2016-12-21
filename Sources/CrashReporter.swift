//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation


struct CrashReporter {
    
    private static var terminalDevice: TerminalDevice? = nil
    
    static func watch(usingDevice device: TerminalDevice) {
        
        CrashReporter.terminalDevice = device
        
        NSSetUncaughtExceptionHandler { _ in
            CrashReporter.report()
        }
        
        signal(SIGABRT) { _ in
            CrashReporter.report()
        }
        
        signal(SIGILL) { _ in
            CrashReporter.report()
        }
        
        signal(SIGSEGV) { _ in
            CrashReporter.report()
        }
        
        signal(SIGFPE) { _ in
            CrashReporter.report()
        }
        
        signal(SIGBUS) { _ in
            CrashReporter.report()
        }
        
        signal(SIGPIPE) { _ in
            CrashReporter.report()
        }
    }
    
    private static func report() {
        
        try? CrashReporter.terminalDevice?.reset()
        
        let stacktrace = Thread.callStackSymbols.joined(separator: "\n")
        
        let title = "Crash detected".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let body =  ("I found the following crash in the app:\n```" + stacktrace + "```")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        CrashReporter.terminalDevice?.flush(TerminalCanvas()
            .reset()
            .clear()
            .text("Oooops.... we are really sorry but slash has crashed ☠️ :\n\nSTACKTRACE:\n\n")
            .text(stacktrace)
            .text("\n\n")
            .text("Please copy this very long link to the browser, to help us with fixing the crash 🙇 \n\nhttps://github.com/slash-hq/slash/issues/new?title=\(title)&body=\(body))\n\n")
            .text("Thank you, \nslash Team\n\n")
        .buffer)
        
        exit(1)
    }
}
