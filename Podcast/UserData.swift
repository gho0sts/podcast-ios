//
//  UserData.swift
//  Podcast
//
//  Created by Drew Dunne on 3/21/18.
//  Copyright © 2018 Cornell App Development. All rights reserved.
//

import UIKit

class UserData: NSObject {
    
    // Stores episode IDs
    typealias EpisodeList = Set<String>

    var bookmarks: EpisodeList!
    var recasts: EpisodeList!
    
    override init() {
        super.init()
        bookmarks = EpisodeList()
        recasts = EpisodeList()
    }
}
