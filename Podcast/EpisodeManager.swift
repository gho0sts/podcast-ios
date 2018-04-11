//
//  EpisodeActions.swift
//  Podcast
//
//  Created by Drew Dunne on 4/5/18.
//  Copyright © 2018 Cornell App Development. All rights reserved.
//

import UIKit

enum EpisodeAction {
    case play
    case bookmark
    case recast
    case share
    case download
    case listenProgress
    case writeDuration(Bool)
}

struct EpisodeUserInfo {
    var isPlaying: Bool
    var downloadStatus: DownloadStatus
    var isBookmarked: Bool
    var isRecasted: Bool
    var listenProgress: Double?
    var durationWritten: Bool
}

class EpisodeManager: NSObject {

//    static let bookmarkChangeNotification = NSNotification.Name(rawValue: "EPISODE_BOOKMARK_CHANGE")
    
    static func consolidateInfo(for episode: Episode) -> EpisodeUserInfo {
        let id = episode.id
        let b = System.currentUserData!.bookmarks.contains(id)
        let r = System.currentUserData!.recasts.contains(id)
        let p = System.currentUserData!.progress[id]
        let dw = System.currentUserData!.durationWritten.contains(id)
        let dl = DownloadManager.shared.status(for: episode.id)
        let playing = Player.sharedInstance.currentEpisode != nil ? Player.sharedInstance.currentEpisode!.id == episode.id : false
        
        return EpisodeUserInfo(isPlaying: playing, downloadStatus: dl, isBookmarked: b, isRecasted: r, listenProgress: p, durationWritten: dw)
    }

    /* dispatches common episode actions
     * Can perform the following:
     *  bookmark
     *  recast
     *  play
     *  download
     *  writeDuration
     */
    static func perform(_ action: EpisodeAction, for episode: Episode) {
        switch action {
        case .bookmark:
            System.currentUserData!.perform(.bookmark, for: episode.id)
        case .recast:
            System.currentUserData!.perform(.recast, for: episode.id)
        case .writeDuration:
            System.currentUserData!.perform(.writeDuration, for: episode.id)
        case .play:
            Player.sharedInstance.playEpisode(episode: episode)
        case .download:
            DownloadManager.shared.handle(episode)
        default:
            return
        }
    }

}
