//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation


class Utils {
    
    class func shell(_ args: String...) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        task.launch()
    }
    
    class func xterm256Color(forUser user: SlackUser) -> Int {
        // Slack API provides a True-Color value for every user (example: 4b3a5a). Terminal supports only 256 colors.
        // Instead of using complex alghoritm for finding the closet color from 256 palette, just get modulo 255 value.
        return (Int(user.color, radix: 16) ?? R.color.messageAuthorTextColor) % 255
    }
}