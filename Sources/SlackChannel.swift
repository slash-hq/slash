//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation

struct SlackChannel {
    
    let id: String
    let name: String
    let members: [String]
    let topic: String
    let general: Bool
    let isMember: Bool
}
