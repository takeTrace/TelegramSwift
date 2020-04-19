//
//  AutoplayPreferences.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11/02/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import SwiftSignalKit


class AutoplayMediaPreferences : PreferencesEntry, Equatable {
    let gifs: Bool
    let videos: Bool
    let soundOnHover: Bool
    let preloadVideos: Bool
    let loopAnimatedStickers: Bool
    init(gifs: Bool, videos: Bool, soundOnHover: Bool, preloadVideos: Bool, loopAnimatedStickers: Bool ) {
        self.gifs = gifs
        self.videos = videos
        self.soundOnHover = soundOnHover
        self.preloadVideos = preloadVideos
        self.loopAnimatedStickers = loopAnimatedStickers
    }
    
    static var defaultSettings: AutoplayMediaPreferences {
        return AutoplayMediaPreferences(gifs: true, videos: true, soundOnHover: true, preloadVideos: true, loopAnimatedStickers: true)
    }
    
    required init(decoder: PostboxDecoder) {
        self.gifs = decoder.decodeInt32ForKey("g", orElse: 0) == 1
        self.videos = decoder.decodeInt32ForKey("v", orElse: 0) == 1
        self.soundOnHover = decoder.decodeInt32ForKey("soh", orElse: 0) == 1
        self.preloadVideos = decoder.decodeInt32ForKey("pv", orElse: 0) == 1
        self.loopAnimatedStickers = decoder.decodeInt32ForKey("las", orElse: 0) == 1
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(gifs ? 1 : 0, forKey: "g")
        encoder.encodeInt32(videos ? 1 : 0, forKey: "v")
        encoder.encodeInt32(soundOnHover ? 1 : 0, forKey: "soh")
        encoder.encodeInt32(preloadVideos ? 1 : 0, forKey: "pv")
        encoder.encodeInt32(loopAnimatedStickers ? 1 : 0, forKey: "las")
    }
    
    static func == (lhs: AutoplayMediaPreferences, rhs: AutoplayMediaPreferences) -> Bool {
        return lhs.gifs == rhs.gifs && lhs.videos == rhs.videos && lhs.soundOnHover == rhs.soundOnHover && lhs.preloadVideos == rhs.preloadVideos && lhs.loopAnimatedStickers == rhs.loopAnimatedStickers
    }
    
    func isEqual(to: PreferencesEntry) -> Bool {
        if let to = to as? AutoplayMediaPreferences {
            return self == to
        } else {
            return false
        }
    }
    
    func withUpdatedAutoplayGifs(_ gifs: Bool) -> AutoplayMediaPreferences {
        return AutoplayMediaPreferences(gifs: gifs, videos: self.videos, soundOnHover: self.soundOnHover, preloadVideos: self.preloadVideos, loopAnimatedStickers: self.loopAnimatedStickers)
    }
    func withUpdatedAutoplayVideos(_ videos: Bool) -> AutoplayMediaPreferences {
        return AutoplayMediaPreferences(gifs: self.gifs, videos: videos, soundOnHover: self.soundOnHover, preloadVideos: self.preloadVideos, loopAnimatedStickers: self.loopAnimatedStickers)
    }
    func withUpdatedAutoplaySoundOnHover(_ soundOnHover: Bool) -> AutoplayMediaPreferences {
        return AutoplayMediaPreferences(gifs: self.gifs, videos: self.videos, soundOnHover: soundOnHover, preloadVideos: self.preloadVideos, loopAnimatedStickers: self.loopAnimatedStickers)
    }
    func withUpdatedAutoplayPreloadVideos(_ preloadVideos: Bool) -> AutoplayMediaPreferences {
        return AutoplayMediaPreferences(gifs: self.gifs, videos: self.videos, soundOnHover: self.soundOnHover, preloadVideos: preloadVideos, loopAnimatedStickers: self.loopAnimatedStickers)
    }
    func withUpdatedLoopAnimatedStickers(_ loopAnimatedStickers: Bool) -> AutoplayMediaPreferences {
        return AutoplayMediaPreferences(gifs: self.gifs, videos: self.videos, soundOnHover: self.soundOnHover, preloadVideos: self.preloadVideos, loopAnimatedStickers: loopAnimatedStickers)
    }
}


func updateAutoplayMediaSettingsInteractively(postbox: Postbox, _ f: @escaping (AutoplayMediaPreferences) -> AutoplayMediaPreferences) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: ApplicationSpecificPreferencesKeys.autoplayMedia, { entry in
            let currentSettings: AutoplayMediaPreferences
            if let entry = entry as? AutoplayMediaPreferences {
                currentSettings = entry
            } else {
                currentSettings = AutoplayMediaPreferences.defaultSettings
            }
            
            return f(currentSettings)
        })
    }
}


func autoplayMediaSettings(postbox: Postbox) -> Signal<AutoplayMediaPreferences, NoError> {
    return postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.autoplayMedia]) |> map { views in
        return views.values[ApplicationSpecificPreferencesKeys.autoplayMedia] as? AutoplayMediaPreferences ?? AutoplayMediaPreferences.defaultSettings
    }
}
