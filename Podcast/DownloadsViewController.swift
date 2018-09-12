//
//  DownloadsViewController.swift
//  Podcast
//
//  Created by Drew Dunne on 2/19/18.
//  Copyright © 2018 Cornell App Development. All rights reserved.
//

import UIKit

class DownloadsViewController: ViewController {
    
    // MARK: Constants
    
    var lineHeight: CGFloat = 3
    var topButtonHeight: CGFloat = 30
    var topViewHeight: CGFloat = 60
    
    // MARK: Variables

    var downloadsTableView: EmptyStateTableView!
    var episodes: [Episode] = []
    var currentlyPlayingIndexPath: IndexPath?
    var isOffline: Bool = false
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    init(isOffline: Bool) {
        self.isOffline = isOffline
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        view.backgroundColor = .paleGrey
        title = "Downloads"
        
        //tableview.
        downloadsTableView = EmptyStateTableView(frame: view.frame, type: .downloads, isRefreshable: true)
        downloadsTableView.emptyStateTableViewDelegate = self
        downloadsTableView.dataSource = self
        downloadsTableView.register(BookmarkTableViewCell.self, forCellReuseIdentifier: "DownloadsTableViewCellIdentifier")
        view.addSubview(downloadsTableView)
        downloadsTableView.rowHeight = BookmarkTableViewCell.height
        mainScrollView = downloadsTableView
        downloadsTableView.emptyStateTableViewDelegate = self
        
        if (isOffline) {
            // TODO: display alert
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Re-Login", style: .plain, target: appDelegate, action: #selector(AppDelegate.exitOfflineMode))
        }
        
        gatherEpisodes()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DownloadManager.shared.delegate = self
    }
    
    func gatherEpisodes() {
        episodes = DownloadManager.shared.downloaded.map { (_, episode) in episode }
        downloadsTableView.endRefreshing()
        downloadsTableView.stopLoadingAnimation()
        downloadsTableView.reloadData()
    }

}

// MARK: TableView Data Source
extension DownloadsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return episodes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DownloadsTableViewCellIdentifier") as! BookmarkTableViewCell
        cell.delegate = self
        let episode = episodes[indexPath.row]
        
        cell.displayView.set(title: episode.title)
        cell.displayView.set(description: episode.descriptionText)
        cell.displayView.set(dateCreated: episode.dateString())
        cell.displayView.set(seriesTitle: episode.seriesTitle)
        cell.displayView.set(title: episode.title)
        if let url = episode.smallArtworkImageURL {
            cell.displayView.set(smallImageUrl: url)
        }
        if let url = episode.largeArtworkImageURL {
            cell.displayView.set(largeImageUrl: url)
        }
        
        cell.displayView.set(topics: episode.topics.map { topic in topic.name })
        cell.displayView.set(duration: episode.duration)
        
        cell.displayView.set(isBookmarked: episode.isBookmarked)
        cell.displayView.set(isRecasted: episode.isRecommended)
        if let blurb = UserEpisodeData.shared.getBlurbForCurrentUser(and: episode) {
            cell.displayView.set(recastBlurb: blurb)
        }
        let downloadStatus = DownloadManager.shared.status(for: episode.id)
        cell.displayView.set(downloadStatus: downloadStatus)
        cell.displayView.set(numberOfRecasts: episode.numberOfRecommendations)
        
        // Custom cell setup
        cell.recommendedButton.isHidden = true

        if episodes[indexPath.row].isPlaying {
            currentlyPlayingIndexPath = indexPath
        }

        return cell
    }

}

// MARK: EmptyStateTableView Delegate
extension DownloadsViewController: EmptyStateTableViewDelegate {

    func didPressEmptyStateViewActionItem() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate, let tabBarController = appDelegate.tabBarController else { return }
        tabBarController.selectedIndex = System.discoverSearchTab
    }

    func emptyStateTableViewHandleRefresh() {
        gatherEpisodes()
    }

}

// MARK: BookmarkTableViewCell Delegate
extension DownloadsViewController: BookmarkTableViewCellDelegate {

    func bookmarkTableViewCellDidPressPlayPauseButton(bookmarksTableViewCell: BookmarkTableViewCell) {
        guard let episodeIndexPath = downloadsTableView.indexPath(for: bookmarksTableViewCell), let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        let episode = episodes[episodeIndexPath.row]
        appDelegate.showAndExpandPlayer()
        Player.sharedInstance.playEpisode(episode: episode)
        bookmarksTableViewCell.updateWithPlayButtonPress(episode: episode)

        // reset previously playings view
        if let playingIndexPath = currentlyPlayingIndexPath, currentlyPlayingIndexPath != episodeIndexPath, let currentlyPlayingCell = downloadsTableView.cellForRow(at: playingIndexPath) as? BookmarkTableViewCell {
            let playingEpisode = episodes[playingIndexPath.row]
            currentlyPlayingCell.updateWithPlayButtonPress(episode: playingEpisode)
        }

        // update index path
        currentlyPlayingIndexPath = episodeIndexPath
    }

    func bookmarkTableViewCellDidPressMoreActionsButton(bookmarksTableViewCell: BookmarkTableViewCell) {
        guard let indexPath = downloadsTableView.indexPath(for: bookmarksTableViewCell) else { return }
        let episode = episodes[indexPath.row]

        let downloadOption = ActionSheetOption(type: DownloadManager.shared.actionSheetType(for: episode.id), action: {
            DownloadManager.shared.handle(episode)
        })

        var header: ActionSheetHeader?

        if let image = bookmarksTableViewCell.episodeImage.image, let title = bookmarksTableViewCell.episodeNameLabel.text, let description = bookmarksTableViewCell.dateTimeLabel.text {
            header = ActionSheetHeader(image: image, title: title, description: description)
        }

        let actionSheetViewController = ActionSheetViewController(options: [downloadOption], header: header)
        showActionSheetViewController(actionSheetViewController: actionSheetViewController)
    }

    func bookmarkTableViewCellDidPressRecommendButton(bookmarksTableViewCell: BookmarkTableViewCell) {
        // Do nothing
    }

}

// MARK: Episode Downloader
extension DownloadsViewController: EpisodeDownloader {

    func didReceive(statusUpdate: DownloadStatus, for episode: Episode) {
        gatherEpisodes()
    }

}
