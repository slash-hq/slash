//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation


struct SlackUser {
    
    enum Presence {
        case active, away
    }
    
    let id: String
    let name: String
    let color: String
    let presence: Presence
}
