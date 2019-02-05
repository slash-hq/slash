//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation

setlocale(LC_CTYPE,"UTF-8")

let device = try TerminalDevice()

CrashReporter.watch(usingDevice: device)

var token: String!

if CommandLine.arguments.count > 1 {
    
    token = CommandLine.arguments[1]
    
} else {
    
    device.flush(TerminalCanvas()
        .clean()
        .cursor(1, 1)
        .text(String(format: R.string.authHelpMessage, SlackOAuth2.address)).buffer)
    
    let slackAuthenticator = SlackOAuth2(clientId: "2296647491.109731100693", clientSecret: "db81eea6c974916693ab746775dbc096", permissions: ["client"])
    
    token = try slackAuthenticator.authenticate()
    
    device.flush(TerminalCanvas().clean().buffer)
}

let application = try Application(usingDevice: device, authenticatedBy: token)

signal(SIGWINCH) { _ in
    application.notifyTerminalSizeHasChanged()
}

application.run()

