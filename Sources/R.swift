//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation

class R {
    
    class string {
        
        // Cool emojis: 🚫❕❗️📢📣🚀🐌🌊💦🌪❄️💥💡🗑⏱🔪💉🌡🚿🎈🎁🏷🔖🔐🔒🔓🔏⚠️💩
    
        static let inputPlaceholder = "Message #%@..."
        
        static let unknownMessageAuthor = "(unknown)"
        
        static let directMessageAuthor = "private"
        
        static let hello = "Connected to %@ team."
        
        static let unknownMessageChannel = "??"
        
        static let connecting = "Connecting 💤 ..."
        
        static let loading = "Loading 💤 ..."
        
        static let connectionError = "⚠️  Connection error occured (%@)"
        
        static let me = "me"
        
        static let authHelpMessage = "🔒  Visit ( %@ ) to login using OAuth2..."
        
        static let authConfirmation =
            "<html><body><center>" +
                "<br><br><img width=\"200\" src=\"https://github.com/slash-hq/slash/blob/master/GitHub/slash_logo_small.png?raw=true\" /><br>" +
                "<h4><span style=\"font-family: Verdana; color: #CCC;\">You can close this window now and continue in the terminal.</span></h4><br>" +
                "<img width=\"600\"src=\"https://github.com/slash-hq/slash/blob/master/GitHub/scr.png?raw=true\"/>" +
            "</center></body></html>"
    }
    
    class color {
        
        // XTERM-256 palette: https://jonasjacek.github.io/colors/
        
        static let defaultBgColor = -1
        
        static let defaulTextColor = -1
        
        static let connectingTextColor = 255
        
        static let helloTextColor = 255
        
        static let commandTextColor = 201
        
        static let userInputTextColor = 231
        
        static let userInputBackgorundColor = 16
        
        static let userInputPlaceholderTextColor = 242
        
        static let userInputSeparatorTextColor = 255
        
        static let messageAuthorTextColor = 158
        
        static let messagePrefixTextColor = 104
        
        static let messageTextColor = 252
        
        static let messageTimeTextColor = 24
        
        static let messageHighlightedBgColor = 154
        
        static let teamNameTextColor = 15
        
        static let teamNameBackgroundColor = 234
        
        static let channelNameTextColor = 38
        
        static let groupNameTextColor = 190
        
        static let directMessageTextColor = 240
        
        static let channelListTextColorAway = 239
        
        static let channelListBgColor = 232
        
        static let channelListBgColorSelected = 15
        
        static let channelListBgColorNotRead = 148
        
        static let messagesListBgColor = 0
        
        static let loadingTextColor = 11
        
        static let linkTextColor = 11
        
        static let mentionTextColor = 37
    }
    
    class dimen {
        
        static let channelsListWidth = 17
    }
}
