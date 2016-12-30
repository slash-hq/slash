//
//  slash
//
//  Copyright © 2016 slash Corp. All rights reserved.
//

import Foundation


class SlackContext {
    
    var teamName : String
    var selfId   : String
    
    var users    = [SlackUser]()
    var channels = [SlackChannel]()
    var groups   = [SlackGroup]()
    var ims      = [SlackIM]()
    
    init(withTeam team: SlackTeam) {
        self.teamName = team.name
        self.selfId = team.selfId
        self.users.append(contentsOf: team.users)
        self.channels.append(contentsOf: team.channels)
        self.groups.append(contentsOf: team.groups)
        self.ims.append(contentsOf: team.ims)
    }
    
    func suggestRecipient(for selection: String?, unreadIds: Set<String> = [], backwardSearch: Bool) -> (id: String, name: String)? {
        
        let channels = self.channels.filter({ $0.isMember }).map { ($0.id, $0.name) }
        let groups = self.groups.map { ($0.id, $0.name) }
        let ims = self.ims.map { im in
            (im.id, (self.users.filter({ $0.id == im.user }).first?.name) ?? "")
        }
        
        let candidates = (channels + groups + ims).filter { unreadIds.isEmpty ? true : (unreadIds.contains($0.0) || $0.0 == selection) }
        
        var suggestion: (id: String, name: String)? = nil
        
        if let current = candidates.index(where: { $0.0 == selection }) {
            if backwardSearch {
                let next = current - 1
                if next < 0 {
                    suggestion = candidates.last
                } else {
                    suggestion = candidates[next]
                }
            } else {
                let next = current + 1
                if next >= candidates.count {
                    suggestion = candidates.first
                } else {
                    suggestion = candidates[next]
                }
            }
        }
        
        return suggestion
    }
    
    func name(forId id: String) -> String? {
        
        var name = self.channels.filter({ $0.id == id }).first?.name
        
        if name == nil {
            name = self.groups.filter({ $0.id == id }).first?.name
        }
        
        if name == nil {
            if let im = self.ims.filter({ $0.id == id }).first {
                if let user = self.users.filter({ $0.id == im.user }).first {
                    name = user.name
                }
            }
        }
        
        if name == nil {
            if let user = self.users.filter({ $0.id == id }).first {
                return user.name
            }
        }
        
        return name
    }
    
    func user(forId id: String) -> SlackUser? {
        return self.users.filter({ $0.id == id }).first
    }
    
    var me: SlackUser? {
        return self.users.filter({ $0.id == self.selfId }).first
    }
    
    var defaultChannel: String? {
        return self.channels.filter({ $0.general }).first?.id
    }

}
