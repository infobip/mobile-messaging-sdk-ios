//
//  MMCallController+ApplicationCalls.swift
//  MobileMessaging
//
//  Created by Svitlovskyi Maksym on 14/03/2023.
//  Copyright © 2023 Infobip Ltd. All rights reserved.
//
import UIKit
#if WEBRTCUI_ENABLED
import InfobipRTC
import AVFoundation
import CallKit
import os.log

extension MMCallController: WebrtcCallEventListener {
    public func onRemoteCameraVideoAdded(_ cameraVideoAddedEvent: CameraVideoAddedEvent) {
        handleRemoteTrackAdded(cameraVideoAddedEvent.track, isScreensharing: false)
    }

    public func onRemoteCameraVideoRemoved() {
        handleRemoteTrackRemoved(isScreensharing: false)
    }

    public func onRemoteScreenShareAdded(_ screenShareAddedEvent: ScreenShareAddedEvent) {
        handleRemoteTrackAdded(screenShareAddedEvent.track, isScreensharing: true)
    }
    public func onRemoteScreenShareRemoved() {
        handleRemoteTrackRemoved(isScreensharing: true)
    }

    public func onRemoteMuted() {
        participantMutedImageV.isHidden = false
    }

    public func onRemoteUnmuted() {
        participantMutedImageV.isHidden = true
    }
}
#endif
