//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//


import Foundation

struct SlackTeam {
    
    let selfId: String
    let name: String
    let users: [SlackUser]
    let channels: [SlackChannel]
    let groups: [SlackGroup]
    let ims: [SlackIM]
    let wssUrl: String
}
