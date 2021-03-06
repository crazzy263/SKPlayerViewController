//
//  PresentedViewController.swift
//  SKPlayerViewControllerExample
//
//  Created by Mark Lagae on 9/15/17.
//  Copyright © 2017 Mark Lagae. All rights reserved.
//

import UIKit

class PresentedViewController: UIViewController, SKPlayerViewControllerDelegate {

    var playerViewController: SKPlayerViewController?
    
    let video = SKVideo(title: "Academica - 10 09 2017",
                        album: "Academica", duration: 2972.300,
                        streamUrl: "http://play.streamkit.tv/content/channel/sperantatv/vod/2017/9/academica_10_09_2017.player.m3u8",
                        thumbnailUrl: "http://space.streamkit.tv/hdd7/content/channel/sperantatv/vod/2017/9/academica_10_09_2017.mp4_medium.jpg",
                        dateCreated: Date(),
                        isLiveStream: false)
    
    // NECESSARY OVERRIDES FOR PLAYER VIEW CONTROLLER
    override var childViewControllerForStatusBarHidden: UIViewController? {
        return playerViewController
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func presentPlayer() {
        self.playerViewController = SKPlayerViewController(video: self.video)
        self.playerViewController?.delegate = self
        self.present(self.playerViewController!, animated: true, completion: nil)
    }
    
    // MARK: - SKPlayerViewControllerDelegate methods 
    func playerViewControllerDidDismissCompletely(_ controller: SKPlayerViewController) {
        // TO PREVENT LEAKS...
        self.playerViewController?.deallocPlayer() // MUST CALL
        self.playerViewController = nil // MUST NIL
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
