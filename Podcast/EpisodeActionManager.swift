//
//  EpisodeActions.swift
//  Podcast
//
//  Created by Drew Dunne on 4/5/18.
//  Copyright © 2018 Cornell App Development. All rights reserved.
//

import UIKit

enum EpisodeAction {
    case bookmark(Bool)
    case recast(Bool, String?)
    case share
    case download
    case listenProgress
    case writeDuration(Bool)
}

class EpisodeActionManager: NSObject {

    static let bookmarkChangeNotification = NSNotification.Name(rawValue: "EPISODE_BOOKMARK_CHANGE")

    /* dispatches common episode actions
     * Can perform the following:
     *  bookmark
     *  recast
     *  listen
     *  writeDuration
     */
    static func perform(_ action: EpisodeAction, for episode: Episode) {
        switch action {
        case .bookmark(let isCreating):
            // Create endpoint request
            let request = BookmarkEndpointRequest(episodeID: episode.id, isCreating: isCreating)
            let id = episode.id
            request.success = { endpoint in
                // only on failure do we want to reverse the changes
                if (isCreating) {
                    System.currentUserData?.bookmarks.insert(id)
                } else {
                    System.currentUserData?.bookmarks.remove(id)
                }
                // Notify
                NotificationCenter.default.post(name: bookmarkChangeNotification, object: id)
            }
            // Notifiy of changes
            NotificationCenter.default.post(name: bookmarkChangeNotification, object: id)
        case .recast(let setValue, _):
            if (setValue) {
                // insert
                System.currentUserData?.recasts.insert(episode.id)
            } else {
                System.currentUserData?.recasts.remove(episode.id)
            }
            // Create endpoint request
            
            // Notifiy of changes
        case .writeDuration(let setValue):
            if (setValue) {
                // insert
                System.currentUserData?.durationWritten.insert(episode.id)
            } else {
                System.currentUserData?.durationWritten.remove(episode.id)
            }
            // Create endpoint request
            
            // Notifiy of changes
        default:
            return
        }
    }

}
