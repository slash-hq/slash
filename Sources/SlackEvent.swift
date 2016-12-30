//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation

enum SlackEvent {
    
    case message(SlackMessage)
    case messageChanged(SlackMessage)
    case messageDeleted(String, String)
    case hello
    case reconnectUrl
    case userTyping(String, String)
    case channelMarked
    case presenceChange(String, SlackUser.Presence)
    case unknown(String)
    case fileCreated
    case filePublic
    case fileShared
    case fileChange
    case prefChange
    case groupMarked
    case mpimMarked
    case imMarked
    case reactionAdded
    case userChange
    case reply(Int, String)
    case teamRename(String)
    case desktopNotification(String, String)
}
