//
//  BookmarkEndpointRequest.swift
//  Podcast
//
//  Created by Drew Dunne on 4/5/18.
//  Copyright © 2018 Cornell App Development. All rights reserved.
//

import UIKit
import SwiftyJSON

class BookmarkEndpointRequest: EndpointRequest {
    
    var episodeID: String
    
    init(episodeID: String, isCreating: Bool) {
        self.episodeID = episodeID
        super.init()
        path = "/bookmarks/\(episodeID)/"
        httpMethod = isCreating ? .post : .delete
    }
    
}
