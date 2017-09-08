//
//  SKPlayerViewController.swift
//  SKPlayerViewControllerExample
//
//  Created by Mark Lagae on 8/28/17.
//  Copyright © 2017 Mark Lagae. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation
import MediaPlayer
import GoogleCast

class SKPlayerViewController: UIViewController {
    
    // MARK: - Variables
    
    private var playbackLikelyToKeepUpContext = 0
    
    private var playUrl: URL!
    
    private var videoIsHLS: Bool = false
    
    private let player = AVPlayer()
    private var playerLayer: AVPlayerLayer!
    
    private var timeObserver: AnyObject!
    
    private var playerRateBeforeSeek: Float = 0
    
    private var volumeView = MPVolumeView()
    private var chromecastButton = GCKUICastButton()
    
    private var airplayEnabled = false {
        didSet {
            self.updateStateForIndependentExternalVars()
        }
    }
    
    private var chromecastEnabled = false {
        didSet {
            self.updateStateForIndependentExternalVars()
        }
    }
    
    private var playerExternalState: SKPlayerExternalState = .none {
        didSet {
            self.playerOverlayView?.state = self.playerExternalState
        }
    }
    
    // Constants for KVO
    private let kPlaybackLikelyToKeepUp = "currentItem.playbackLikelyToKeepUp"
    private let kPlaybackBufferEmpty = "currentItem.playbackBufferEmpty"
    private let kPlaybackBufferFull = "currentItem.playbackBufferFull"
    private let kPlayerStatus = "currentItem.status"
    
    private let kStatusBarFrame = "statusBarFrame"
    
    // Tap Gesture Recognizer for showing / hiding view
    private let hideTapGestureRecognizer = UITapGestureRecognizer()
    
    // Dismiss/Present Stuff
    private var proxyView: UIView? // View to save position of embeded self (if needed)
    
    private var isEmbeded = false // default value
    private var isFullscreen = false { // default value
        didSet {
            self.updateFullscreenImage()
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return isFullscreen || (UIApplication.shared.statusBarOrientation == .landscapeLeft || UIApplication.shared.statusBarOrientation == .landscapeRight)
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
    
    private var statusBarHeight: CGFloat = UIApplication.shared.statusBarFrame.height != 0 ? UIApplication.shared.statusBarFrame.height : 20.0
    
    // MARK: Interface Builder Connections
    @IBOutlet weak var airplayContainer: UIView?
    @IBOutlet weak var chromecastContainer: UIView?
    
    @IBOutlet weak var playPauseButton: UIButton?
    
    @IBOutlet weak var timeElapsedLabel: UILabel?
    @IBOutlet weak var timeRemainingLabel: UILabel?
    
    @IBOutlet weak var seekSlider: UISlider?
    
    @IBOutlet weak var fullscreenButton: UIButton?
    
    @IBOutlet weak var bottomBarContainer: UIView?
    @IBOutlet weak var topBarContainer: UIView?
    @IBOutlet weak var statusBarBacking: UIView?
    
    @IBOutlet weak var bufferingIndicator: UIActivityIndicatorView?
    
    @IBOutlet weak var hlsLabel: UILabel?
    
    @IBOutlet weak var playerOverlayView: SKPlayerOverlayView?
    
    // MARK: Config
    let playImageName: String = "sk_play"
    let playColor: UIColor = UIColor.black
    let playHighlightedColor: UIColor = UIColor.white
    let playDisabledColor: UIColor = UIColor(red: 128/255, green: 128/255, blue: 128/255, alpha: 1.0)
    
    let pauseImageName: String = "sk_pause"
    let pauseColor: UIColor = UIColor.black
    let pauseHighlightedColor: UIColor = UIColor.white
    let pauseDisabledColor: UIColor = UIColor(red: 128/255, green: 128/255, blue: 128/255, alpha: 1.0)
    
    let airplayImageName: String = "sk_airplay"
    let airplayOffColor: UIColor = UIColor.black
    let airplayOnColor: UIColor = UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1.0)
    let airplayHighlightedColor: UIColor = UIColor.white
    
    let chromecastImageName: String = "sk_chromecast"
    let chromecastOffColor: UIColor = UIColor.black
    let chromecastOnColor: UIColor = UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1.0)
    let chromecastHighlightedColor: UIColor = UIColor.white
    
    let fullScreenImageName: String = "sk_fullscreen"
    let fullScreenColor: UIColor = UIColor.black
    let fullScreenHighlightedColor: UIColor = UIColor.white
    
    let normalScreenImageName: String = "sk_normalscreen"
    let normalScreenColor: UIColor = UIColor.black
    let normalScreenHighlightedColor: UIColor = UIColor.white
    
    // MARK: -
    
    // MARK: Inits
    
    init(url: URL, isLiveStream: Bool = false) {
        super.init(nibName: "SKPlayerViewController", bundle: nil)
        
        self.playUrl = url
        self.videoIsHLS = isLiveStream
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.black
        
        // setup UI actions
        self.addActionsToOutlets()
        
        // Setup the playerLayer
        self.playerLayer = AVPlayerLayer(player: player)
        view.layer.insertSublayer(playerLayer, at: 0)
        
        let playerItem = AVPlayerItem(url: self.playUrl)
        self.player.replaceCurrentItem(with: playerItem)
        
        // Setup KVO
        self.player.addObserver(self, forKeyPath: kPlaybackLikelyToKeepUp, options: .new, context: nil)
        self.player.addObserver(self, forKeyPath: kPlaybackBufferFull, options: .new, context: nil)
        self.player.addObserver(self, forKeyPath: kPlaybackBufferEmpty, options: .new, context: nil)
        self.player.addObserver(self, forKeyPath: kPlayerStatus, options: [.new, .initial], context: nil)
        
        //UIApplication.shared.addObserver(self, forKeyPath: kStatusBarFrame, options: [.new, .initial], context: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(SKPlayerViewController.updateLocalStatusBarFrameHeight), name: .UIApplicationDidChangeStatusBarFrame, object: nil)
        
        // Setup the time observer
        let timeInterval = CMTimeMakeWithSeconds(1.0, 10)
        self.timeObserver = self.player.addPeriodicTimeObserver(forInterval: timeInterval, queue: DispatchQueue.main, using: { (elapsedTime: CMTime) in
            
            self.updateTimeLabelsWith(elapsedTime: Float(CMTimeGetSeconds(elapsedTime)), duration: Float(CMTimeGetSeconds(self.player.currentItem!.duration)))
            self.updateSeekSliderWith(elapsedTime: Float(CMTimeGetSeconds(elapsedTime)), duration: Float(CMTimeGetSeconds(self.player.currentItem!.duration)))
            
            // Check if buffering indicator needed
            self.updateBufferingIndicatorIfNeeded()
            
        }) as AnyObject
        
        self.setSeekSliderThumbImage()
        
        // Set target for tap gesture recognizer
        self.hideTapGestureRecognizer.addTarget(self, action: #selector(SKPlayerViewController.toggleControlsHidden(sender:)))
        self.view.addGestureRecognizer(self.hideTapGestureRecognizer)
        
        self.updateUIForHLSIfNeeded()
        
        self.addExternalPlayerButtons()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if self.parent != nil && self.presentingViewController == nil {
            self.isEmbeded = true
            self.isFullscreen = false
        } else {
            self.isEmbeded = false
            self.isFullscreen = true
        }
        
        self.playPlayer() // Start playback
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        self.playerLayer.frame = self.view.bounds
    }
    
    // MARK: - UI Initial Config Functions
    
    private func setSeekSliderThumbImage() {
        self.seekSlider?.setThumbImage(#imageLiteral(resourceName: "sk_seek_thumb_image"), for: .normal)
    }
    
    // MARK: - Outlet Functions
    
    private func addActionsToOutlets() {
        // In this function we will programmatically add all the actions to buttons and sliders.
        
        // Playpause button
        self.playPauseButton?.addTarget(self, action: #selector(SKPlayerViewController.playPause), for: .touchUpInside)
        
        // Seek slider
        self.seekSlider?.addTarget(self, action: #selector(SKPlayerViewController.sliderBeganTracking), for: .touchDown)
        self.seekSlider?.addTarget(self, action: #selector(SKPlayerViewController.sliderEndedTracking), for: .touchUpInside)
        self.seekSlider?.addTarget(self, action: #selector(SKPlayerViewController.sliderEndedTracking), for: .touchUpOutside)
        self.seekSlider?.addTarget(self, action: #selector(SKPlayerViewController.sliderValueChanged), for: .valueChanged)
        
        self.fullscreenButton?.addTarget(self, action: #selector(SKPlayerViewController.toggleFullScreen), for: .touchUpInside)
    }
    
    private func addExternalPlayerButtons() {
        self.addAirplayButton()
        self.addChromecastButton()
    }
    
    private func addAirplayButton() {
        self.volumeView.showsVolumeSlider = false
        self.volumeView.sizeToFit()
        
        self.volumeView.frame = self.airplayContainer!.bounds
        
        // Customization
        let airplayBaseImage = UIImage(named: airplayImageName)
        let airplayOffImage = airplayBaseImage?.maskWith(color: airplayOffColor)
        self.volumeView.setRouteButtonImage(airplayOffImage, for: .normal)
        
        let airplayHighlightedImage = airplayBaseImage?.maskWith(color: airplayHighlightedColor)
        self.volumeView.setRouteButtonImage(airplayHighlightedImage, for: .highlighted)
        
        let airplayOnImage = airplayBaseImage?.maskWith(color: airplayOnColor)
        self.volumeView.setRouteButtonImage(airplayOnImage, for: .selected)
        
        self.airplayContainer?.addSubview(self.volumeView)
        self.airplayContainer?.backgroundColor = UIColor.clear
        
        NotificationCenter.default.addObserver(self, selector: #selector(SKPlayerViewController.wirelessRouteActiveChanged), name: .MPVolumeViewWirelessRouteActiveDidChange, object: nil)
    }
    
    private func addChromecastButton() {
        
        self.chromecastButton.frame = self.chromecastContainer!.bounds
        self.chromecastButton.tintColor = UIColor.black
        
        self.chromecastContainer?.addSubview(self.chromecastButton)
        self.chromecastContainer?.backgroundColor = UIColor.clear
    }
    
    
    @objc private func playPause() {
        let isPlaying = self.player.rate > 0
        if isPlaying {
            self.pausePlayer()
        } else {
            self.playPlayer()
        }
    }
    
    private func playPlayer() {
        
        let pauseBaseImage = UIImage(named: pauseImageName)!
        
        let pauseImage = pauseBaseImage.maskWith(color: pauseColor)
        self.playPauseButton?.setImage(pauseImage, for: .normal)
        
        let pauseHighlightedImage = pauseBaseImage.maskWith(color: pauseHighlightedColor)
        self.playPauseButton?.setImage(pauseHighlightedImage, for: .highlighted)
        self.playPauseButton?.setImage(pauseHighlightedImage, for: .selected)
        
        let pauseDisabledImage = pauseBaseImage.maskWith(color: pauseDisabledColor)
        self.playPauseButton?.setImage(pauseDisabledImage, for: .disabled)
        
        self.player.play()
    }
    
    private func pausePlayer() {
        
        let playBaseImage = UIImage(named: playImageName)!
        
        let playImage = playBaseImage.maskWith(color: playColor)
        self.playPauseButton?.setImage(playImage, for: .normal)
        
        let playHighlightedImage = playBaseImage.maskWith(color: playHighlightedColor)
        self.playPauseButton?.setImage(playHighlightedImage, for: .highlighted)
        self.playPauseButton?.setImage(playHighlightedImage, for: .selected)
        
        let playDisabledImage = playBaseImage.maskWith(color: playDisabledColor)
        self.playPauseButton?.setImage(playDisabledImage, for: .disabled)
        
        self.player.pause()
    }
    
    @objc private func sliderBeganTracking() {
        self.playerRateBeforeSeek = self.player.rate
        self.pausePlayer()
    }
    
    @objc private func sliderEndedTracking() {
        let videoDuration = Float(CMTimeGetSeconds(self.player.currentItem!.duration))
        let elapsedTime = videoDuration * seekSlider!.value
        
        let timescale = self.player.currentItem!.asset.duration.timescale
        
        self.updateTimeLabelsWith(elapsedTime: elapsedTime, duration: videoDuration)
        
        self.showBufferingIndiciator()
        
        self.player.seek(to: CMTimeMakeWithSeconds(Float64(elapsedTime), timescale), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero) { (completed) in
            self.hideBufferingIndicator()
            self.playPlayer()
        }
    }
    
    @objc private func sliderValueChanged() {
        let videoDuration = Float(CMTimeGetSeconds(self.player.currentItem!.duration))
        let elapsedTime = videoDuration * seekSlider!.value
        
        self.updateTimeLabelsWith(elapsedTime: elapsedTime, duration: videoDuration)
    }
    
    @objc private func toggleFullScreen() {
        
        if isEmbeded {
            if isFullscreen {
                self.exitFullScreenToEmbed()
            } else {
                self.enterFullScreenFromEmbed()
            }
        } else {
            self.dismissCompletely()
        }
    }
    
    // MARK: - UI Update Functions
    
    private func updateUIForHLSIfNeeded() {
        if self.videoIsHLS {
            self.seekSlider?.isHidden = true
            self.timeElapsedLabel?.isHidden = true
            self.timeRemainingLabel?.isHidden = true
            
            self.hlsLabel?.isHidden = false
        } else {
            self.seekSlider?.isHidden = false
            self.timeElapsedLabel?.isHidden = false
            self.timeRemainingLabel?.isHidden = false
            
            self.hlsLabel?.isHidden = true
        }
    }
    
    private func disablePlayPauseButton() {
        self.playPauseButton?.isEnabled = false
        self.pausePlayer()
    }
    
    private func enablePlayPauseButton() {
        self.playPauseButton?.isEnabled = true
        self.playPlayer()
    }
    
    private func updateTimeLabelsWith(elapsedTime: Float, duration: Float) {
        
        if !self.videoIsHLS {
            
            self.timeElapsedLabel?.text = hmsToString(hms: secondsToHoursMinutesSeconds(seconds: Int(roundf(elapsedTime)))) // Basically convert seconds to the time string
            let timeRemaining = duration - elapsedTime
            
            if timeRemaining.isFinite {
                self.timeRemainingLabel?.text = "-\(hmsToString(hms: secondsToHoursMinutesSeconds(seconds: Int(roundf(Float(timeRemaining))))))"
            }
        }
    }
    
    private func updateSeekSliderWith(elapsedTime: Float, duration: Float) {
        
        if !self.videoIsHLS {
            
            let progress = elapsedTime / duration
            self.seekSlider?.setValue(progress, animated: true)
        }
    }
    
    @objc private func toggleControlsHidden(sender: UITapGestureRecognizer) {

        let point = sender.location(in: self.view)
        let tappedView = self.view.hitTest(point, with: nil)
        if tappedView == self.view || tappedView?.restorationIdentifier == "overlayView" {
            
            if self.topBarContainer!.isHidden || self.bottomBarContainer!.isHidden {
                // Show
                self.showControls()
            } else {
                // Hide
                self.hideControls()
            }
        }
    }
    
    private func hideControls() {
        UIView.animate(withDuration: 0.25, animations: {
            self.topBarContainer?.alpha = 0
            self.bottomBarContainer?.alpha = 0
            self.statusBarBacking?.alpha = 0
        }) { (_) in
            self.topBarContainer?.isHidden = true
            self.bottomBarContainer?.isHidden = true
            self.statusBarBacking?.isHidden = true
        }
    }
    
    private func showControls() {
        self.topBarContainer?.isHidden = false
        self.bottomBarContainer?.isHidden = false
        self.statusBarBacking?.isHidden = false
        UIView.animate(withDuration: 0.25, animations: {
            self.topBarContainer?.alpha = 1
            self.bottomBarContainer?.alpha = 1
            self.statusBarBacking?.alpha = 1
        })
    }
    
    private func updateBufferingIndicatorIfNeeded() {
        
        let likelyToKeepUp = self.player.currentItem!.isPlaybackLikelyToKeepUp
        let bufferFull = self.player.currentItem!.isPlaybackBufferFull
        let bufferEmpty = self.player.currentItem!.isPlaybackBufferEmpty
        
        if (likelyToKeepUp || bufferFull) && !self.bufferingIndicator!.isHidden {
            self.hideBufferingIndicator()
        }
        
        if bufferEmpty && self.bufferingIndicator!.isHidden {
            self.showBufferingIndiciator()
        }
    }
    
    private func showBufferingIndiciator() {
        self.disablePlayPauseButton()
        self.bufferingIndicator?.startAnimating()
        self.bufferingIndicator?.isHidden = false
    }
    
    private func hideBufferingIndicator() {
        self.enablePlayPauseButton()
        self.bufferingIndicator?.stopAnimating()
    }
    
    // Fullscreen stuff.
    
    private func enterFullScreenFromEmbed() {
        
        self.proxyView = UIView(frame: self.view.frame)
        self.proxyView?.isHidden = true
        self.proxyView?.autoresizingMask = self.view.autoresizingMask
        self.view.superview?.addSubview(self.proxyView!)
        
        // Now set the frame to the screen frame
        let frame = self.view.window?.convert(self.view.frame, from: self.proxyView?.superview)
        self.view.window?.addSubview(self.view)
        self.view.frame = frame!
        
        self.isFullscreen = true
        
        UIView.animate(withDuration: 0.25) { 
            self.view.frame = self.view.window!.bounds
            self.view.layoutIfNeeded()
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    private func exitFullScreenToEmbed() {
        
        var frame = self.view.window?.convert(self.view.frame, to: self.proxyView?.superview)
        self.proxyView?.superview?.addSubview(self.view)
        
        if !(UIApplication.shared.statusBarOrientation == .landscapeRight || UIApplication.shared.statusBarOrientation == .landscapeLeft) {
            frame?.origin.y -= self.statusBarHeight
        }
        
        self.view.frame = frame!
        
        self.isFullscreen = false
        
        UIView.animate(withDuration: 0.25, animations: {
            
            self.view.frame = self.proxyView!.frame
            
            self.view.layoutIfNeeded()
            self.setNeedsStatusBarAppearanceUpdate()
        }) { (_) in
            self.proxyView?.removeFromSuperview()
            self.proxyView = nil
        }
    }
    
    private func dismissCompletely() {
        self.dismiss(animated: true, completion: nil)
    }
    
    private func updateFullscreenImage() {
        
        if self.isFullscreen {
            
            let baseNormalScreenImage = UIImage(named: normalScreenImageName)
            
            let normalscreenImage = baseNormalScreenImage?.maskWith(color: normalScreenColor)
            self.fullscreenButton?.setImage(normalscreenImage, for: .normal)
            
            let highlightedNormalscreenImage = baseNormalScreenImage?.maskWith(color: normalScreenHighlightedColor)
            self.fullscreenButton?.setImage(highlightedNormalscreenImage, for: .selected)
            self.fullscreenButton?.setImage(highlightedNormalscreenImage, for: .highlighted)
            
        } else {
            
            let baseFullScreenImage = UIImage(named: fullScreenImageName)
            
            let fullscreenImage = baseFullScreenImage?.maskWith(color: fullScreenColor)
            self.fullscreenButton?.setImage(fullscreenImage, for: .normal)
            
            let highlightedFullscreenImage = baseFullScreenImage?.maskWith(color: fullScreenHighlightedColor)
            self.fullscreenButton?.setImage(highlightedFullscreenImage, for: .selected)
            self.fullscreenButton?.setImage(highlightedFullscreenImage, for: .highlighted)
        }
        
    }
    
    @objc private func wirelessRouteActiveChanged() {
        
        self.airplayEnabled = self.volumeView.isWirelessRouteActive
        
    }
    
    // MARK: - Utility Functions
    
    private func updateStateForIndependentExternalVars() {
        
        // Update the state for airplay and chromecast states
        
        if self.airplayEnabled && self.chromecastEnabled {
            
            self.playerExternalState = .both
            return
            
        } else if self.airplayEnabled {
            
            self.playerExternalState = .airplay
            return
            
        } else if self.chromecastEnabled {
            
            self.playerExternalState = .chromecast
            return
            
        } else {
            
            self.playerExternalState = .none
            return
    
        }
    }
    
    // HMS
    private func secondsToHoursMinutesSeconds (seconds : Int) -> (Int, Int, Int) {
        return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }
    
    private func hmsToString(hms: (Int, Int, Int)) -> String {
        
        let (h, m, s) = hms
        
        var stringTime = ""
        
        if h > 0 {
            // Add the hour to the result string
            
            stringTime += String(h)
            stringTime += ":"
            stringTime += String(format: "%02d", m) // Add leading zeroes if hour is > 0
            
        } else {
            // Only keep the minute and second
            stringTime += String(m)
        }
        
        // Add seconds
        stringTime += ":"
        stringTime += String(format: "%02d", s) // Add leading zeroes for seconds
        
        return stringTime
    }
    
    @objc private func updateLocalStatusBarFrameHeight() {
        let height = UIApplication.shared.statusBarFrame.height
        if height > 0 {
            self.statusBarHeight = height
        }
    }
    
    // MARK: -
    
    // MARK: KVO
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath! {
        case kPlaybackLikelyToKeepUp:
            self.hideBufferingIndicator()
            self.playPlayer()
        case kPlaybackBufferFull:
            self.hideBufferingIndicator()
            self.playPlayer()
        case kPlaybackBufferEmpty:
            self.showBufferingIndiciator()
        case kPlayerStatus:
            if self.player.currentItem!.status == .readyToPlay {
                self.hideBufferingIndicator()
            } else {
                self.showBufferingIndiciator()
            }
        case kStatusBarFrame:
            print(UIApplication.shared.statusBarFrame.height)
        default:
            break
        }
    }
    
    deinit {
        self.player.removeTimeObserver(self.timeObserver)
        self.player.removeObserver(self, forKeyPath: kPlaybackLikelyToKeepUp)
        self.player.removeObserver(self, forKeyPath: kPlaybackBufferFull)
        self.player.removeObserver(self, forKeyPath: kPlaybackBufferEmpty)
        self.player.removeObserver(self, forKeyPath: kPlayerStatus)
        
        UIApplication.shared.removeObserver(self, forKeyPath: kStatusBarFrame)
    }
    
    // MARK: -
}
