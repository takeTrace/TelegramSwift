//
//  MGalleryGIFItem.swift
//  TelegramMac
//
//  Created by keepcoder on 16/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import TGUIKit
class MGalleryGIFItem: MGalleryItem {

    override init(_ context: AccountContext, _ entry: GalleryEntry, _ pagerSize: NSSize) {
        super.init(context, entry, pagerSize)
        
        let view = self.view
        let pathSignal = path.get() |> map { path in
           return AVGifData.dataFrom(path)
        } |> distinctUntilChanged |> deliverOnMainQueue |> mapToSignal { data -> Signal<Tuple2<AVGifData?,GIFPlayerView>, NoError> in
            return view.get() |> distinctUntilChanged |> map { view in
                return Tuple(data, view as! GIFPlayerView)
            }
        }
        disposable.set(pathSignal.start(next: { tuple in
            tuple._1.set(data: tuple._0)
        }))
        
    }
    
    override var status:Signal<MediaResourceStatus, NoError> {
        return chatMessageFileStatus(account: context.account, file: media)
    }
    
    var media:TelegramMediaFile {
        switch entry {
        case .message(let entry):
            if let media = entry.message!.media[0] as? TelegramMediaFile {
                return media
            } else if let media = entry.message!.media[0] as? TelegramMediaWebpage {
                switch media.content {
                case let .Loaded(content):
                    return content.file!
                default:
                    fatalError("")
                }
            }
        case .instantMedia(let media, _):
            return media.media as! TelegramMediaFile
        default:
            fatalError()
        }
        
        fatalError("")
    }
    
//    override var maxMagnify:CGFloat {
//        return 1.0
//    }

    override func singleView() -> NSView {
        let player = GIFPlayerView()
        player.layerContentsRedrawPolicy = .duringViewResize
        return player
    }
    
    override var sizeValue: NSSize {
        if let size = media.dimensions?.size {
            return size.fitted(pagerSize)
        }
        return pagerSize
    }
    
    override func request(immediately: Bool) {
        
        let signal:Signal<ImageDataTransformation,NoError> = chatMessageVideo(postbox: context.account.postbox, fileReference: entry.fileReference(media), scale: System.backingScale)
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: sizeValue, boundingSize: sizeValue, intrinsicInsets: NSEdgeInsets())
        let result = signal |> deliverOn(graphicsThreadPool) |> mapToThrottled { generator -> Signal<CGImage?, NoError> in
            return .single(generator.execute(arguments, generator.data)?.generateImage())
        }
        
    
        path.set(context.account.postbox.mediaBox.resourceData(media.resource) |> mapToSignal { (resource) -> Signal<String, NoError> in
            if resource.complete {
                return .single(link(path:resource.path, ext:kMediaGifExt)!)
            }
            return .never()
        })

        self.image.set(result |> map { .image($0 != nil ? NSImage(cgImage: $0!, size: $0!.backingSize) : nil, nil) } |> deliverOnMainQueue)
    
        fetch()
    }
    
 
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    override func fetch() -> Void {
        fetching.set(chatMessageFileInteractiveFetched(account: context.account, fileReference: entry.fileReference(media)).start())
    }

    
}
