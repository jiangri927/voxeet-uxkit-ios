//
//  ConferenceViewController+VTConferenceDelegate.swift
//  VoxeetUXKit
//
//  Created by Corentin Larroque on 16/02/2017.
//  Copyright © 2017 Voxeet. All rights reserved.
//

import VoxeetSDK

extension ConferenceViewController: VTConferenceDelegate {
    func participantJoined(userID: String, stream: MediaStream) {
        // Monkey patch: Wait WebRTC media to be started (avoids sound button to blink).
        if conferenceStartTimer == nil {
            conferenceStartTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(conferenceStarted), userInfo: nil, repeats: false)
        }
        
        if userID != VoxeetSDK.shared.session.user?.id {
            // Begin active speaker timer.
            activeSpeaker.begin()
            
            // Hide conference state when a user joins the conference.
            conferenceStateLabel.isHidden = true
            conferenceStateLabel.text = nil
            
            // Stop outgoing sound when a user enters in conference.
            outgoingSound?.stop()
            
            // Update user's audio position to listen each users clearly in a 3D environment.
            updateUserPosition()
        }
        
        // Update streams and UI.
        participantUpdated(userID: userID, stream: stream)
    }
    
    func participantUpdated(userID: String, stream: MediaStream) {
        let sessionService = VoxeetSDK.shared.session
        let conferenceService = VoxeetSDK.shared.conference
        
        if userID == sessionService.user?.id {
            // Attach own stream to the own video renderer.
            if !stream.videoTracks.isEmpty {
                ownVideoRenderer.attach(userID: userID, stream: stream)
                // Enable camera button (in case of `join` method with `video` true).
                actionBarVC.cameraButton(state: .on)
            }
        } else {
            // Append / Refresh users' collection view.
            if let user = conferenceService.user(userID: userID) {
                usersVC.append(user: user)
            }
            // Refresh active speaker.
            activeSpeaker.refresh()
        }
        
        // Show / Hide own video renderer or refresh active speaker.
        if let sessionUserID = sessionService.user?.id {
            if !(conferenceService.mediaStream(userID: sessionUserID)?.videoTracks.isEmpty ?? true) {
                if !conferenceService.users.filter({ $0.hasStream }).isEmpty {
                    isOwnVideoRendererHidden(false)
                } else {
                    activeSpeaker.refresh()
                }
            } else {
                if !conferenceService.users.filter({ $0.hasStream }).isEmpty {
                    isOwnVideoRendererHidden(true)
                } else {
                    activeSpeaker.refresh()
                }
            }
        }
    }
    
    func participantLeft(userID: String) {
        let conferenceService = VoxeetSDK.shared.conference
        
        if userID != VoxeetSDK.shared.session.user?.id {
            // Reload collection view to update/remove inactive users.
            let usersConfiguration = VoxeetUXKit.shared.conferenceController?.configuration.users
            if let user = conferenceService.user(userID: userID), (usersConfiguration?.displayLeftUsers ?? false) {
                usersVC.update(user: user)
            } else {
                usersVC.remove(userID: userID)
            }
            
            // Refresh / End active speaker timer.
            if conferenceService.users.isEmpty {
                activeSpeaker.end()
            } else {
                activeSpeaker.refresh()
            }
            
            // Hide / Unhide own renderer.
            if conferenceService.users.filter({ $0.hasStream }).isEmpty {
                isOwnVideoRendererHidden(true)
                
                // Update conference state label.
                if conferenceStateLabel.text == nil {
                    conferenceStateLabel.text = VTUXLocalized.string("VTUX_CONFERENCE_STATE_CALLING")
                }
                conferenceStateLabel.isHidden = false
            }
            
            // Update user's audio position to listen each users clearly in a 3D environment.
            updateUserPosition()
        }
    }
    
    func screenShareStarted(userID: String, stream: MediaStream) {
        if userID == VoxeetSDK.shared.session.user?.id { return }
        let user = VoxeetSDK.shared.conference.user(userID: userID)
        
        if !stream.videoTracks.isEmpty {
            // Stop active speaker and lock current user.
            screenShareUserID = userID
            usersVC.lock(user: user)
            activeSpeaker.end()
            
            // Attach screen share stream.
            speakerVideoContentFill = speakerVideoVC.videoRenderer.contentFill
            speakerVideoVC.unattach()
            speakerVideoVC.attach(userID: userID, stream: stream)
            speakerVideoVC.contentFill(false, animated: false)
            speakerVideoVC.view.isHidden = false
            
            // Disable screen share button.
            actionBarVC.screenShareButton(state: .on)
            actionBarVC.screenShareButton.isEnabled(false, animated: true)
        }
    }
    
    func screenShareStopped(userID: String) {
        if userID == VoxeetSDK.shared.session.user?.id { return }
        
        // Unattach screen share stream.
        speakerVideoVC.unattach()
        speakerVideoVC.contentFill(speakerVideoContentFill, animated: false)
        speakerVideoVC.view.isHidden = true
        
        // Reset active speaker and unlock previous user.
        screenShareUserID = nil
        usersVC.lock(user: nil)
        activeSpeaker.begin()
        activeSpeaker.refresh()
        
        // Enable screen share button.
        actionBarVC.screenShareButton(state: .off)
        actionBarVC.screenShareButton.isEnabled(true, animated: true)
    }
    
    func messageReceived(userID: String, message: String) {}
    
    private func isOwnVideoRendererHidden(_ isHidden: Bool) {
        UIView.animate(withDuration: 0.125, animations: {
            self.ownVideoRenderer.alpha = !isHidden && !self.isMinimized ? 1 : 0
            self.flipImage.alpha = self.ownVideoRenderer.alpha
        })
    }
    
    private func updateUserPosition() {
        let users = VoxeetSDK.shared.conference.users.filter({ $0.hasStream })
        let sliceAngle = Double.pi / Double(users.count)
        
        for (index, user) in users.enumerated() {
            let angle = ((Double.pi / 2) - (Double.pi - (sliceAngle * Double(index) + sliceAngle / 2))) / (Double.pi / 2)
            if let userID = user.id {
                VoxeetSDK.shared.conference.userPosition(userID: userID, angle: angle, distance: 0.2)
            }
        }
    }
}