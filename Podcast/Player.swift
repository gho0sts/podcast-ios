
import UIKit
import AVFoundation
import MediaPlayer
import Kingfisher

class ListeningDuration {
    var id: String
    var currentProgress: Double
    var percentageListened: Double
    var realDuration: Double?

    init(id: String, currentProgress: Double, percentageListened: Double, realDuration: Double?) {
        self.id = id
        self.currentProgress = currentProgress
        self.percentageListened = percentageListened
        self.realDuration = realDuration
    }
}

protocol PlayerDelegate: class {
    func updateUIForEpisode(episode: Episode)
    func updateUIForPlayback()
    func updateUIForEmptyPlayer()
}


protocol RecastPlayer {
    func play()
    func pause()
    func seek(to: CMTime, completion: (() -> ())?)
    func reset()
    func isPlaying() -> Bool
    func playItem(with url: URL)
    var rate: Float { get set }
    var duration: TimeInterval? { get }
    var currentTime: CMTime? { get }
}

class AVPlayerWrapper: NSObject, RecastPlayer {

    private var player: AVPlayer
    private var autoplayEnabled: Bool = true
    private var currentItemPrepared: Bool = false

    // KVO
    private var playerItemContext: UnsafeMutableRawPointer?

    override init() {
        player = AVPlayer()
        player.automaticallyWaitsToMinimizeStalling = false
    }

    deinit {
        removeCurrentItemStatusObserver()
    }

    func play() {
        if let currentItem = player.currentItem {
            if currentItem.status == .readyToPlay {
                try! AVAudioSession.sharedInstance().setActive(true)

            } else {
                autoplayEnabled = true
            }
        }
    }

    func pause() {
        if let currentItem = player.currentItem {
            if currentItem.status == .readyToPlay {
                player.pause()
            } else {
                autoplayEnabled = false
            }
        }
    }

    func playItem(with url: URL) {
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: ["playable"])
        playerItem.addObserver(self,
                               forKeyPath: #keyPath(AVPlayerItem.status),
                               options: [.old, .new],
                               context: &playerItemContext)
        player.replaceCurrentItem(with: playerItem)
    }

    func isPlaying() -> Bool {
        return player.rate != 0.0 || (!currentItemPrepared && autoplayEnabled && (player.currentItem != nil))
    }

    var rate: Float {
        get {
            return player.rate
        }
        set(newValue) {
            player.rate = newValue
        }
    }

    var duration: TimeInterval? {
        if let duration = player.currentItem?.duration, !duration.isIndefinite  {
            return duration.seconds
        }
        return nil
    }

    var currentTime: CMTime? {
        return player.currentItem?.currentTime()
    }

    func reset() {
        autoplayEnabled = true
        currentItemPrepared = false
        removeCurrentItemStatusObserver()
    }

    func seek(to: CMTime, completion: (() -> ())?) {
        guard let currentItem = player.currentItem else { return }
        player.currentItem?.seek(to: to, completionHandler: { _ in completion?() })
    }

    func removeCurrentItemStatusObserver() {
        // observeValue(...) will take care of removing AVPlayerItem.status observer once it is
        // readyToPlay, so we only need to remove observer if AVPlayerItem isn't readyToPlay yet
        if let currentItem = player.currentItem {
            if currentItem.status != .readyToPlay {
                currentItem.removeObserver(self,
                                           forKeyPath: #keyPath(AVPlayer.status),
                                           context: &playerItemContext)
            }
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // Only handle observations for the playerItemContext
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }

        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItemStatus

            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItemStatus(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }

            switch status {
            case .readyToPlay:
                print("AVPlayerItem ready to play")
                currentItemPrepared = true
                if autoplayEnabled { play() }
            case .failed:
                print("Failed to load AVPlayerItem")
                return
            case .unknown:
                print("Unknown AVPlayerItemStatus")
                return
            }
            // remove observer after having reading the AVPlayerItem status
            player.currentItem?.removeObserver(self,
                                               forKeyPath: #keyPath(AVPlayerItem.status),
                                               context: &playerItemContext)
        }
    }
}

class AVAudioPlayerWrapper: RecastPlayer {

    private var player: AVAudioPlayer?

    init() {

    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func isPlaying() -> Bool {
        return player?.isPlaying ?? false
    }

    func playItem(with url: URL) {
        guard let _ = try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback),
            let _ = try? AVAudioSession.sharedInstance().setActive(true) else { return }

        player = try! AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        //audioPlayer.addObserver(self, forKeyPath: "rate", options: .new, context: nil)
        player?.isMeteringEnabled = true
        player?.enableRate = true
        play()
    }

    var rate: Float {
        get {
            return player?.rate ?? 0.0
        }
        set(newValue) {
            player?.rate = rate
        }
    }

    var duration: TimeInterval? {
        return player?.duration
    }

    var currentTime: CMTime? {
        return Player.sharedInstance.doubleToTime(player?.currentTime ?? 0)
    }

    func seek(to: CMTime, completion: (() -> ())?) {
        player?.play(atTime: to.seconds)
        completion?()
    }

    func reset() {

    }
}

enum PlayerRate: Float {
    case one = 1
    case zero_5 = 0.5
    case one_25 = 1.25
    case one_5 = 1.5
    case one_75 = 1.75
    case two = 2
    
    func toString() -> String {
        switch self {
        case .one, .two:
            return String(Int(self.rawValue)) + "x"
        default:
            return "\(self.rawValue)x"
        }
    }
}

class Player: NSObject {
    static let sharedInstance = Player()
    private override init() {
        isScrubbing = false
        savedRate = .one
        avPlayer = AVPlayerWrapper()
        audioPlayer = AVAudioPlayerWrapper()
        super.init()
        
        configureCommands()
    }
    
    deinit {
        removeTimeObservers()
    }
    
    weak var delegate: PlayerDelegate?
    
    // Mark: KVO variables
    private var timeObserverToken: Any?
    
    // Mark: Playback variables/methods
    
    private var avPlayer: AVPlayerWrapper
    private var audioPlayer: AVAudioPlayerWrapper!
    private var player: RecastPlayer {
        get {
            if let current = currentEpisode, current.isDownloaded, trimSilence {
                return audioPlayer
            }
            return avPlayer
        }
        set { }
    }

    private(set) var currentEpisode: Episode?
    private var currentTimeAt: Double = 0.0
    private var currentEpisodePercentageListened: Double = 0.0
    private var nowPlayingInfo: [String: Any]?
    private var artworkImage: MPMediaItemArtwork?

    var trimSilence: Bool = true
    var listeningDurations: [String: ListeningDuration] = [:]
    var isScrubbing: Bool
    var isPlaying: Bool { return player.isPlaying()}
    var savedRate: PlayerRate

    func resetUponLogout() {
        saveListeningDurations()
        listeningDurations = [:]
        pause()
    }
    
    func playEpisode(episode: Episode) {
        if currentEpisode?.id == episode.id {
            currentEpisode?.currentProgress = getProgress()
            // if the same episode was set we just toggle the player
            togglePlaying()
            return
        }

        saveListeningDurations()
        
        var url: URL?
        if episode.isDownloaded {
            if let filepath = episode.fileURL {
                url = filepath
            } else if let httpURL = episode.audioURL {
                url = httpURL
            }
        } else {
            if let httpURL = episode.audioURL {
                url = httpURL
            }
        }
        guard let u = url else {
            print("Episode \(episode.title) mp3URL is nil. Unable to play.")
            return
        }
        
        // cleanup any previous AVPlayerItem
        reset()
        pause()

        if let listeningDuration = listeningDurations[episode.id] { // if we've played this episode before
            currentTimeAt = listeningDuration.currentProgress
        } else {
            listeningDurations[episode.id] = ListeningDuration(id: episode.id, currentProgress: episode.currentProgress, percentageListened: 0, realDuration: nil)
            currentTimeAt = episode.currentProgress
        }

        currentEpisode?.isPlaying = false
        episode.isPlaying = true
        currentEpisode = episode

        player.playItem(with: u)

        updateNowPlayingArtwork()
        updateNowPlayingInfo()
        delegate?.updateUIForEpisode(episode: currentEpisode!)
        delegate?.updateUIForPlayback()
    }

    func trim(url: URL) {
        var amplitudes: [Float] = []

        var timeElapsed = 0.0

        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { (Timer) in

            timeElapsed += 0.1
//
//            self.audioPlayer.updateMeters()
//            amplitudes.append(self.audioPlayer.averagePower(forChannel: 0) + 120.0)

            print("--------")
            print("rate: \(self.audioPlayer.rate)")
            print("--------")

            if amplitudes.last! > 50 {
                print(amplitudes.max()! - amplitudes.last!)
                self.audioPlayer.rate = 1.0 + (amplitudes.max()! - amplitudes.last!) * 0.01
            } else {
                self.audioPlayer.rate = 1.0 + (amplitudes.max()! - amplitudes.last!) * 0.02
            }
            print(self.audioPlayer.rate)

            print("timeElapsed: \(timeElapsed)")
        }
    }
    
    @objc func play() {
        player.rate = savedRate.rawValue
        setProgress(progress: currentTimeAt, completion: { self.player.play() })
        delegate?.updateUIForPlayback()
        updateNowPlayingInfo()
        addTimeObservers()
    }
    
    @objc func pause() {
        player.pause()
        updateNowPlayingInfo()
        removeTimeObservers()
        delegate?.updateUIForPlayback()
    }
    
    func togglePlaying() {
        if isPlaying {
            pause()
        } else {
            play()
        }
        delegate?.updateUIForPlayback()
    }
    
    func reset() {
        isScrubbing = false
        player.rate = 1.0
        player.reset()
    }
    
    func skip(seconds: Double) {
        guard let current = player.currentTime else { return }
        let newTime = CMTimeAdd(current, CMTime(seconds: seconds, preferredTimescale: CMTimeScale(1.0)))
        player.seek(to: newTime, completion: { self.updateNowPlayingInfo() })
        if newTime > CMTime(seconds: 0.0, preferredTimescale: CMTimeScale(1.0)) {
            delegate?.updateUIForPlayback()
        }
    }
    
    func setSpeed(rate: PlayerRate) {
        savedRate = rate
        if isPlaying {
            player.rate = rate.rawValue
        }
        delegate?.updateUIForPlayback()
    }
    
    func getSpeed() -> PlayerRate {
        return savedRate
    }
    
    func getProgress() -> Double {
        if let duration = player.duration, duration != 0, let currentTime = player.currentTime {
            return currentTime.seconds / duration
        }
        return 0.0
    }

    func getDuration() -> Double {
        return player.duration ?? 0.0
    }

    func doubleToTime(_ d: Double) -> CMTime? {
        if let duration = player.duration {
            return CMTime(seconds: duration * min(max(d, 0.0), 1.0), preferredTimescale: CMTimeScale(1.0))
        }
        return nil
    }
    
    func setProgress(progress: Double, completion: (() -> ())? = nil) {
        if let time = doubleToTime(progress) {
            player.seek(to: time, completion: {
                completion?()
                self.isScrubbing = false
                self.currentTimeAt = self.getProgress()
                self.delegate?.updateUIForPlayback()
                self.updateNowPlayingInfo()
            })
        }
    }
    
    func seekTo(_ position: TimeInterval) {
        updateCurrentPercentageListened()
        let newPosition = CMTimeMakeWithSeconds(position, 1)
        player.seek(to: newPosition, completion: {
            self.currentTimeAt = self.getProgress()
            self.delegate?.updateUIForPlayback()
            self.updateNowPlayingInfo()
        })
    }
    
    // Configures the Remote Command Center for our player. Should only be called once (in init)
    func configureCommands() {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.pauseCommand.addTarget(self, action: #selector(Player.pause))
        commandCenter.playCommand.addTarget(self, action: #selector(Player.play))
        commandCenter.skipForwardCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            self.skip(seconds: 30)
            return .success
        }
        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipBackwardCommand.addTarget { (event) -> MPRemoteCommandHandlerStatus in
            self.skip(seconds: -30)
            return .success
        }
        commandCenter.skipBackwardCommand.preferredIntervals = [30]
        commandCenter.changePlaybackPositionCommand.addTarget(self, action: #selector(Player.handleChangePlaybackPositionCommandEvent(event:)))
    }
    
    @objc func handleChangePlaybackPositionCommandEvent(event: MPChangePlaybackPositionCommandEvent) -> MPRemoteCommandHandlerStatus {
        seekTo(event.positionTime)
        return .success
    }
    
    // Updates information in Notfication Center/Lockscreen info
    func updateNowPlayingInfo() {
        guard let episode = currentEpisode else {
            configureNowPlaying(info: nil)
            return
        }
        
        var nowPlayingInfo = [
            MPMediaItemPropertyTitle: episode.title,
            MPMediaItemPropertyArtist: episode.seriesTitle,
            MPMediaItemPropertyAlbumTitle: episode.seriesTitle,
            MPNowPlayingInfoPropertyPlaybackRate: NSNumber(value: savedRate.rawValue),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: NSNumber(value: CMTimeGetSeconds(currentItemElapsedTime())),
            MPMediaItemPropertyPlaybackDuration: NSNumber(value: CMTimeGetSeconds(currentItemDuration())),
        ] as [String : Any]
        
        if let image = artworkImage {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = image
        }
        configureNowPlaying(info: nowPlayingInfo)
    }
    
    // Updates the now playing artwork.
    func updateNowPlayingArtwork() {
        guard let episode = currentEpisode, let url = episode.smallArtworkImageURL else {
            return
        }
        
        ImageCache.default.retrieveImage(forKey: episode.id, options: nil) {
            image, cacheType in
            if let image = image {
                //In this code snippet, the `cacheType` is .disk
                self.artworkImage = MPMediaItemArtwork(boundsSize: CGSize(width: image.size.width, height: image.size.height), requestHandler: { _ in
                    image
                })
                self.updateNowPlayingInfo()
            } else {
                ImageDownloader.default.downloadImage(with: url, options: [], progressBlock: nil) {
                    (imageDown, error, url, data) in
                    if let imageDown = imageDown {
                        ImageCache.default.store(imageDown, forKey: episode.id)
                        self.artworkImage = MPMediaItemArtwork(boundsSize: CGSize(width: imageDown.size.width, height: imageDown.size.height), requestHandler: { _ in
                            imageDown
                        })
                        self.updateNowPlayingInfo()
                    }
                }
            }
        }
    }
    
    // Configures the MPNowPlayingInfoCenter
    func configureNowPlaying(info: [String : Any]?) {
        self.nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // Warning: these next three functions should only be used to set UI element values
    
    func currentItemDuration() -> CMTime {
        return doubleToTime(player.duration ?? 0) ?? CMTime(seconds: 0.0, preferredTimescale: CMTimeScale(1.0))
    }
    
    func currentItemElapsedTime() -> CMTime {
        return player.currentTime ?? CMTime(seconds: 0.0, preferredTimescale: CMTimeScale(1.0))
    }
    
    func currentItemRemainingTime() -> CMTime {
        return CMTimeSubtract(currentItemDuration(), currentItemElapsedTime())
    }
    
    // Mark: KVO methods
    
    func addTimeObservers() {
//        timeObserverToken = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(1.0, Int32(NSEC_PER_SEC)), queue: DispatchQueue.main, using: { [weak self] _ in
//            self?.delegate?.updateUIForPlayback()
//        })
//        NotificationCenter.default.addObserver(self, selector: #selector(currentItemDidPlayToEndTime), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }
    
    func removeTimeObservers() {
//        guard let token = timeObserverToken else { return }
//        player.removeTimeObserver(token)
//        timeObserverToken = nil
//        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }
    
    @objc func currentItemDidPlayToEndTime() {
        removeTimeObservers()
        delegate?.updateUIForPlayback()
    }

    func updateCurrentPercentageListened() {
        currentEpisodePercentageListened += abs(getProgress() - currentTimeAt)
        currentTimeAt = getProgress()
    }

    func saveListeningDurations() {
        if let current = currentEpisode {
            current.currentProgress = getProgress() // set episodes current progress
            if let listeningDuration = listeningDurations[current.id] {
                listeningDuration.currentProgress = getProgress()
                listeningDuration.realDuration = getDuration()
                updateCurrentPercentageListened()
                listeningDuration.percentageListened = listeningDuration.percentageListened + currentEpisodePercentageListened
                currentEpisodePercentageListened = 0
            } else {
                print("Trying to save an episode never played before: \(current.title)")
            }
        }
        let endpointRequest = SaveListeningDurationEndpointRequest(listeningDurations: listeningDurations)
        endpointRequest.success = { _ in
            print("Successfully saved listening duration history")
        }
        endpointRequest.failure = { _ in
            print("Unsuccesfully saved listening duration history")
        }
        System.endpointRequestQueue.addOperation(endpointRequest)
    }
}
