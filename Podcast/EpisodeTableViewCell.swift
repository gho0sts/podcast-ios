//
//  EpisodeTableViewCell.swift
//  Podcast
//
//  Created by Drew Dunne on 2/25/17.
//  Copyright © 2017 Cornell App Development. All rights reserved.
//

import UIKit
import SnapKit

protocol EpisodeTableViewCellDelegate: class {
    func episodeTableView(didPress action: EpisodeAction, on cell: EpisodeTableViewCell)
    func episodeTableView(didPressMoreActionsOn cell: EpisodeTableViewCell)
    
//    func episodeTableViewCellDidPressPlayPauseButton(episodeTableViewCell: EpisodeTableViewCell)
//    func episodeTableViewCellDidPressRecommendButton(episodeTableViewCell: EpisodeTableViewCell)
//    func episodeTableViewCellDidPressBookmarkButton(episodeTableViewCell: EpisodeTableViewCell)
//    func episodeTableViewCellDidPressMoreActionsButton(episodeTableViewCell: EpisodeTableViewCell)
}

class EpisodeTableViewCell: UITableViewCell, EpisodeSubjectViewDelegate {
    
    var episodeSubjectView: EpisodeSubjectView!
    
    weak var delegate: EpisodeTableViewCellDelegate?
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        
        episodeSubjectView = EpisodeSubjectView()
        contentView.addSubview(episodeSubjectView)
        
        episodeSubjectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // This is gross. But it's too broken
        episodeSubjectView.delegate = self 
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setup(with episode: Episode, and info: EpisodeUserInfo) {
        episodeSubjectView.setup(with: episode, and: info)
    }
    
    func update(with userInfo: EpisodeUserInfo) {
        
    }

//    func updateWithPlayButtonPress(episode: Episode) {
//        episodeSubjectView.updateWithPlayButtonPress(episode: episode)
//    }
    
    ///
    /// Mark: Delegate
    ///
    func setBookmarkButtonToState(isBookmarked: Bool) {
        episodeSubjectView.episodeUtilityButtonBarView.setBookmarkButtonToState(isBookmarked: isBookmarked)
    }
    
    func setRecommendedButtonToState(isRecommended: Bool, numberOfRecommendations: Int) {
        episodeSubjectView.episodeUtilityButtonBarView.setRecommendedButtonToState(isRecommended: isRecommended, numberOfRecommendations: numberOfRecommendations)
    }
    
    func episodeSubjectViewDidPressPlayPauseButton(episodeSubjectView: EpisodeSubjectView) {
        delegate?.episodeTableView(didPress: .play, on: self)
    }
    
    func episodeSubjectViewDidPressRecommendButton(episodeSubjectView: EpisodeSubjectView) {
        delegate?.episodeTableView(didPress: .recast, on: self)
    }
    
    func episodeSubjectViewDidPressBookmarkButton(episodeSubjectView: EpisodeSubjectView) {
        delegate?.episodeTableView(didPress: .bookmark, on: self)
    }
    
    func episodeSubjectViewDidPressMoreActionsButton(episodeSubjectView: EpisodeSubjectView) {
        delegate?.episodeTableView(didPressMoreActionsOn: self)
    }
}




