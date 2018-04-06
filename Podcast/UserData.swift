//
//  UserData.swift
//  Podcast
//
//  Created by Drew Dunne on 3/21/18.
//  Copyright © 2018 Cornell App Development. All rights reserved.
//

import UIKit

class UserData: NSObject {
    
    enum UserAction {
        case bookmark
        case recast
        case writeDuration
        case subscribe
        case follow
    }
    
    enum UserStoreAction {
        case listen
    }

    // if ID contained in list, then that episode is bookmarked
    var bookmarks: Set<String>!
    var recasts: Set<String>!
    var durationWritten: Set<String>!
    var subscriptions: Set<String>!
    var following: Set<String>!
    
    // ID to listening progress
    var progress: [String: Double]!
    
    override init() {
        super.init()
        
        bookmarks = Set<String>()
        recasts = Set<String>()
        durationWritten = Set<String>()
        subscriptions = Set<String>()
        following = Set<String>()
        
        progress = [:]
    }
    
    func list(for action: UserAction) -> Set<String> {
        switch action {
        case .bookmark: return bookmarks
        case .recast: return recasts
        case .writeDuration: return durationWritten
        case .subscribe: return subscriptions
        case .follow: return following
        }
    }
    
    func endpoint(for action: UserAction) -> EndpointRequest {
        switch action {
        case .bookmark: return EndpointRequest()
        case .recast: return EndpointRequest()
        case .writeDuration: return EndpointRequest()
        case .subscribe: return EndpointRequest()
        case .follow: return EndpointRequest()
        }
    }
    
    func notification(for action: UserAction) -> String {
        switch action {
        case .bookmark: return ""
        case .recast: return ""
        case .writeDuration: return ""
        case .subscribe: return ""
        case .follow: return ""
        }
    }
    
    func bookmark(id: String) {
        bookmarks.insert(id)
    }
    
    func unbookmark(id: String) {
        bookmarks.remove(id)
    }
    
    func isBookmarked(id: String) -> Bool {
        return bookmarks.contains(id)
    }
    
    func perform(_ action: UserAction, for id: String, value: Bool) {
        var store = list(for: action)
        if value {
            store.insert(id)
        } else {
            store.remove(id)
        }
        // post notification
        let request = endpoint(for: action)
        request.success = { endpoint in
            // post notification
        }
        request.failure = { endpoint in
            // post notification
        }
    }
    
    func perform(_ action: UserAction, for id: String) {
        perform(action, for: id, value: !list(for: action).contains(id))
    }
    
}
