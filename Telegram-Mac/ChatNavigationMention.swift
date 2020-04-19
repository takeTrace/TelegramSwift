//
//  ChatNavigationMention.swift
//  Telegram
//
//  Created by keepcoder on 15/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox


class ChatNavigationMention: ImageButton {

    private var badge:BadgeNode?
    private var badgeView:View = View()

    override init() {
        super.init()
        autohighlight = false
        set(image: theme.icons.chatMention, for: .Normal)
        set(image: theme.icons.chatMentionActive, for: .Highlight)
        self.setFrameSize(60,60)
        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 5
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.1)
        shadow.shadowOffset = NSMakeSize(0, 2)
        self.shadow = shadow
        
    }
    
    func updateCount(_ count: Int32) {
        if count > 0 {
            badge = BadgeNode(.initialize(string: Int(count).prettyNumber, color: .white, font: .bold(.small)), theme.colors.accent)
            badge!.view = badgeView
            badgeView.setFrameSize(badge!.size)
            addSubview(badgeView)
        } else {
            badgeView.removeFromSuperview()
        }
        needsLayout = true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        set(image: theme.icons.chatMention, for: .Normal)
        set(image: theme.icons.chatMentionActive, for: .Highlight)
    }
    
    override func scrollWheel(with event: NSEvent) {
        
    }
    
    override func layout() {
        super.layout()
        badgeView.centerX(y:0)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    
}
