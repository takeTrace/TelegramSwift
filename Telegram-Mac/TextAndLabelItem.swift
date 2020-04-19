//
//  TextAndLabelItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

class TextAndLabelItem: GeneralRowItem {


    
    private var labelStyle:ControlStyle = ControlStyle()
    private var textStyle:ControlStyle = ControlStyle()

    private var label:NSAttributedString
    
    var labelLayout:(TextNodeLayout, TextNode)?
    var textLayout:TextViewLayout
    let isTextSelectable:Bool
    let callback:()->Void
    let canCopy: Bool
    init(_ initialSize:NSSize, stableId:AnyHashable, label:String, labelColor: NSColor = theme.colors.accent, text:String, context: AccountContext, viewType: GeneralViewType = .legacy, detectLinks:Bool = false, isTextSelectable:Bool = true, callback:@escaping ()->Void = {}, openInfo:((PeerId, Bool, MessageId?, ChatInitialAction?)->Void)? = nil, hashtag:((String)->Void)? = nil, selectFullWord: Bool = false, canCopy: Bool = true) {
        self.callback = callback
        self.isTextSelectable = isTextSelectable
        self.label = NSAttributedString.initialize(string: label, color: labelColor, font: .normal(FontSize.text))
        let attr = NSMutableAttributedString()
        _ = attr.append(string: text.trimmed.fullTrimmed, color: theme.colors.text, font: .normal(.title))
        if detectLinks {
            attr.detectLinks(type: [.Links, .Hashtags, .Mentions], context: context, color: theme.colors.link, openInfo: openInfo, hashtag: hashtag, applyProxy: { settings in
                applyExternalProxy(settings, accountManager: context.sharedContext.accountManager)
            })
        }
        self.canCopy = canCopy
        
        
        textLayout = TextViewLayout(attr, alwaysStaticItems: !detectLinks)
        textLayout.interactions = globalLinkExecutor
        textLayout.selectWholeText = !detectLinks
        if selectFullWord {
            textLayout.interactions.copy = {
                copyToClipboard(text)
                return true
            }
        }
        
        super.init(initialSize,stableId: stableId, type: .none, viewType: viewType, action: callback, drawCustomSeparator: true)
    }
    
    override func viewClass() -> AnyClass {
        return TextAndLabelRowView.self
    }
    
    var textWidth:CGFloat {
        switch viewType {
        case .legacy:
            return width - inset.left - inset.right
        case let .modern(_, inner):
            return blockWidth - inner.left - inner.right
        }
    }
    
    override var height: CGFloat {
        switch viewType {
        case .legacy:
            return labelsHeight + 20
        case let .modern(_, insets):
            return labelsHeight + insets.top + insets.bottom - 4
        }
    }
    
    var labelsHeight:CGFloat {
        var inset:CGFloat = 0
        if let labelLayout = labelLayout {
            inset = labelLayout.0.size.height
        }
        return (textLayout.layoutSize.height + inset + 4)
    }
    
    var textY:CGFloat {
        var inset:CGFloat = 0
        if let labelLayout = labelLayout {
            inset = labelLayout.0.size.height
        }
        return ((height - labelsHeight) / 2.0) + inset + 4.0
    }
    
    var labelY:CGFloat {
        return (height - labelsHeight) / 2.0
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        if !canCopy {
            return .single([])
        } else {
            return .single([ContextMenuItem(L10n.textCopyLabel(self.label.string.components(separatedBy: " ").map{$0.capitalizingFirstLetter()}.joined(separator: " ")), handler: { [weak self] in
                if let strongSelf = self {
                    copyToClipboard(strongSelf.textLayout.attributedString.string)
                }
            })])
        }
       
    }
//
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let result = super.makeSize(width, oldWidth: oldWidth)
        textLayout.measure(width: textWidth)
        labelLayout = TextNode.layoutText(maybeNode: nil,  label, nil, 1, .end, NSMakeSize(textWidth, .greatestFiniteMagnitude), nil, false, .left)
        return result
    }
    
}

class TextAndLabelRowView: GeneralRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private var labelView:TextView = TextView()
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        if let item = item as? TextAndLabelItem, let label = item.labelLayout, layer == containerView.layer {
            switch item.viewType {
            case .legacy:
                label.1.draw(NSMakeRect(item.inset.left, item.labelY, label.0.size.width, label.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backdorColor)
                if item.drawCustomSeparator {
                    ctx.setFillColor(theme.colors.border.cgColor)
                    ctx.fill(NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left - item.inset.right, .borderSize))
                }
            case let .modern(position, insets):
                label.1.draw(NSMakeRect(insets.left, item.labelY, label.0.size.width, label.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backdorColor)
                if position.border {
                    ctx.setFillColor(theme.colors.border.cgColor)
                    ctx.fill(NSMakeRect(insets.left, self.containerView.frame.height - .borderSize, self.containerView.frame.width - insets.left - insets.right, .borderSize))
                }
            }
        }
        
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    override func updateColors() {
        if let item = item as? TextAndLabelItem {
            self.labelView.backgroundColor = backdorColor
            self.containerView.backgroundColor = backdorColor
            self.background = item.viewType.rowBackground
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if mouseInside() {
            if let item = item as? TextAndLabelItem {
                item.action()
            }
        } else {
            super.mouseUp(with: event)
        }
    }
    

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.addSubview(labelView)
        self.addSubview(self.containerView)
        self.containerView.displayDelegate = self
        self.containerView.userInteractionEnabled = false
        labelView.set(handler: { [weak self] _ in
            if let item = self?.item as? TextAndLabelItem {
                item.action()
            }
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        if let item = item as? TextAndLabelItem {
            switch item.viewType {
            case .legacy:
                self.containerView.frame = bounds

                if let _ = item.labelLayout {
                    labelView.setFrameOrigin(item.inset.left, item.textY)
                } else {
                    labelView.centerY(x:item.inset.left)
                }
            case let .modern(position, innerInsets):
                self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)

                if let _ = item.labelLayout {
                    labelView.setFrameOrigin(innerInsets.left, item.textY)
                } else {
                    labelView.centerY(x: innerInsets.left)
                }
            }
            self.containerView.setCorners(item.viewType.corners)

        }
        
    }
    
    
    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        
        if let item = item as? TextAndLabelItem {
           // labelView.userInteractionEnabled = item.isTextSelectable
            labelView.userInteractionEnabled = item.canCopy
            labelView.isSelectable = item.isTextSelectable
            labelView.update(item.textLayout)
        }
        containerView.needsDisplay = true
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
