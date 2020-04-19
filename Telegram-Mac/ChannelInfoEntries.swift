//
//  ChannelInfoEntries.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore
import SyncCore
import TGUIKit
import SwiftSignalKit


struct ChannelInfoEditingState: Equatable {
    let editingName: String?
    let editingDescriptionText: String
    
    init(editingName:String? = nil, editingDescriptionText:String = "") {
        self.editingName = editingName
        self.editingDescriptionText = editingDescriptionText
    }
    
    func withUpdatedEditingDescriptionText(_ editingDescriptionText: String) -> ChannelInfoEditingState {
        return ChannelInfoEditingState(editingName: self.editingName, editingDescriptionText: editingDescriptionText)
    }
    
    static func ==(lhs: ChannelInfoEditingState, rhs: ChannelInfoEditingState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.editingDescriptionText != rhs.editingDescriptionText {
            return false
        }
        return true
    }
}


class ChannelInfoState: PeerInfoState {
    
    let editingState: ChannelInfoEditingState?
    let savingData: Bool
    let updatingPhotoState:PeerInfoUpdatingPhotoState?
    
    init(editingState: ChannelInfoEditingState?, savingData: Bool, updatingPhotoState: PeerInfoUpdatingPhotoState?) {
        self.editingState = editingState
        self.savingData = savingData
        self.updatingPhotoState = updatingPhotoState
    }
    
    override init() {
        self.editingState = nil
        self.savingData = false
        self.updatingPhotoState = nil
    }
    
    func isEqual(to: PeerInfoState) -> Bool {
        if let to = to as? ChannelInfoState {
            return self == to
        }
        return false
    }
    
    static func ==(lhs: ChannelInfoState, rhs: ChannelInfoState) -> Bool {
        if lhs.editingState != rhs.editingState {
            return false
        }
        if lhs.savingData != rhs.savingData {
            return false
        }
        
        return lhs.updatingPhotoState == rhs.updatingPhotoState
        

    }
    
    func withUpdatedEditingState(_ editingState: ChannelInfoEditingState?) -> ChannelInfoState {
        return ChannelInfoState(editingState: editingState, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState)
    }
    
    func withUpdatedSavingData(_ savingData: Bool) -> ChannelInfoState {
        return ChannelInfoState(editingState: self.editingState, savingData: savingData, updatingPhotoState: self.updatingPhotoState)
    }
    
    func withUpdatedUpdatingPhotoState(_ f: (PeerInfoUpdatingPhotoState?) -> PeerInfoUpdatingPhotoState?) -> ChannelInfoState {
        return ChannelInfoState(editingState: self.editingState, savingData: self.savingData, updatingPhotoState: f(self.updatingPhotoState))
    }
    func withoutUpdatingPhotoState() -> ChannelInfoState {
        return ChannelInfoState(editingState: self.editingState, savingData: self.savingData, updatingPhotoState: nil)
    }
}

private func valuesRequiringUpdate(state: ChannelInfoState, view: PeerView) -> (title: String?, description: String?) {
    if let peer = view.peers[view.peerId] as? TelegramChannel {
        var titleValue: String?
        var descriptionValue: String?
        if let editingState = state.editingState {
            if let title = editingState.editingName, title != peer.title {
                titleValue = title
            }
            if let cachedData = view.cachedData as? CachedChannelData {
                if let about = cachedData.about {
                    if about != editingState.editingDescriptionText {
                        descriptionValue = editingState.editingDescriptionText
                    }
                } else if !editingState.editingDescriptionText.isEmpty {
                    descriptionValue = editingState.editingDescriptionText
                }
            }
        }
        
        return (titleValue, descriptionValue)
    } else {
        return (nil, nil)
    }
}

class ChannelInfoArguments : PeerInfoArguments {
    
    private let reportPeerDisposable = MetaDisposable()
    private let updatePeerNameDisposable = MetaDisposable()
    private let toggleSignaturesDisposable = MetaDisposable()
    private let updatePhotoDisposable = MetaDisposable()
    func updateState(_ f: (ChannelInfoState) -> ChannelInfoState) -> Void {
        updateInfoState { state -> PeerInfoState in
            return f(state as! ChannelInfoState)
        }
    }
    
    override func dismissEdition() {
        updateState { state in
            return state.withUpdatedSavingData(false).withUpdatedEditingState(nil)
        }
    }
    
    override func updateEditable(_ editable: Bool, peerView: PeerView) {
        
        let context = self.context
        let peerId = self.peerId
        let updateState:((ChannelInfoState)->ChannelInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        
        if editable {
            if let peer = peerViewMainPeer(peerView), let cachedData = peerView.cachedData as? CachedChannelData {
                updateState { state -> ChannelInfoState in
                    return state.withUpdatedEditingState(ChannelInfoEditingState(editingName: peer.displayTitle, editingDescriptionText: cachedData.about ?? ""))
                }
            }
        } else {
            var updateValues: (title: String?, description: String?) = (nil, nil)
            updateState { state in
                updateValues = valuesRequiringUpdate(state: state, view: peerView)
                if updateValues.0 != nil || updateValues.1 != nil {
                    return state.withUpdatedSavingData(true)
                } else {
                    return state.withUpdatedEditingState(nil)
                }
            }
            
            
            
            let updateTitle: Signal<Void, NoError>
            if let titleValue = updateValues.title {
                updateTitle = updatePeerTitle(account: context.account, peerId: peerId, title: titleValue)
                    |> `catch` { _ in return .complete() }
            } else {
                updateTitle = .complete()
            }
            
            let updateDescription: Signal<Void, NoError>
            if let descriptionValue = updateValues.description {
                updateDescription = updatePeerDescription(account: context.account, peerId: peerId, description: descriptionValue.isEmpty ? nil : descriptionValue)
                    |> `catch` { _ in return .complete() }
            } else {
                updateDescription = .complete()
            }
            
            let signal = combineLatest(updateTitle, updateDescription)
            
            updatePeerNameDisposable.set(showModalProgress(signal: (signal |> deliverOnMainQueue), for: context.window).start(error: { _ in
                updateState { state in
                    return state.withUpdatedSavingData(false)
                }
            }, completed: {
                updateState { state in
                    return state.withUpdatedSavingData(false).withUpdatedEditingState(nil)
                }
            }))
        }

        
    }
    
    func visibilitySetup() {
        let setup = ChannelVisibilityController(context, peerId: peerId)
        _ = (setup.onComplete.get() |> deliverOnMainQueue).start(next: { [weak self] _ in
            self?.pullNavigation()?.back()
        })
        pushViewController(setup)
    }
    
    func setupDiscussion() {
        _ = (self.context.account.postbox.loadedPeerWithId(self.peerId) |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let `self` = self {
                self.pushViewController(ChannelDiscussionSetupController(context: self.context, peer: peer))
            }
        })
    }
    
    func toggleSignatures( _ enabled: Bool) -> Void {
        toggleSignaturesDisposable.set(toggleShouldChannelMessagesSignatures(account: context.account, peerId: peerId, enabled: enabled).start())
    }
    
    func members() -> Void {
        pushViewController(ChannelMembersViewController(context, peerId: peerId))
    }
    
    func admins() -> Void {
        pushViewController(ChannelAdminsViewController(context, peerId: peerId))
    }
    
    func blocked() -> Void {
        pushViewController(ChannelBlacklistViewController(context, peerId: peerId))
    }
    
    func updatePhoto(_ path:String) -> Void {
        
        let updateState:((ChannelInfoState)->ChannelInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        
        let cancel = { [weak self] in
            self?.updatePhotoDisposable.dispose()
            updateState { state -> ChannelInfoState in
                return state.withoutUpdatingPhotoState()
            }
        }
        
        let context = self.context
        let peerId = self.peerId
        /*
         filethumb(with: URL(fileURLWithPath: path), account: account, scale: System.backingScale) |> mapToSignal { res -> Signal<String, NoError> in
         guard let image = NSImage(contentsOf: URL(fileURLWithPath: path)) else {
         return .complete()
         }
         let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: image.size, boundingSize: NSMakeSize(640, 640), intrinsicInsets: NSEdgeInsets())
         if let image = res(arguments)?.generateImage() {
         return putToTemp(image: NSImage(cgImage: image, size: image.backingSize))
         }
         return .complete()
         }
 */
        let updateSignal = Signal<String, NoError>.single(path) |> map { path -> TelegramMediaResource in
            return LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
        } |> beforeNext { resource in
            
            updateState { (state) -> ChannelInfoState in
                return state.withUpdatedUpdatingPhotoState { previous -> PeerInfoUpdatingPhotoState? in
                    return PeerInfoUpdatingPhotoState(progress: 0, cancel: cancel)
                }
            }
            
        } |> mapError {_ in return UploadPeerPhotoError.generic} |> mapToSignal { resource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
            return  updatePeerPhoto(postbox: context.account.postbox, network: context.account.network, stateManager: context.account.stateManager, accountPeerId: context.account.peerId, peerId: peerId, photo: uploadedPeerPhoto(postbox: context.account.postbox, network: context.account.network, resource: resource), mapResourceToAvatarSizes: { resource, representations in
                return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
            })
        }
                

        updatePhotoDisposable.set((updateSignal |> deliverOnMainQueue).start(next: { status in
            updateState { state -> ChannelInfoState in
                switch status {
                case .complete:
                    return state
                case let .progress(progress):
                    return state.withUpdatedUpdatingPhotoState { previous -> PeerInfoUpdatingPhotoState? in
                        return previous?.withUpdatedProgress(progress)
                    }
                }
            }
        }, error: { error in
            updateState { (state) -> ChannelInfoState in
                return state.withoutUpdatingPhotoState()
            }
        }, completed: { 
            updateState { (state) -> ChannelInfoState in
                return state.withoutUpdatingPhotoState()
            }
        }))
        

    }
    
    func stats(_ datacenterId: Int32) {
        self.pushViewController(ChannelStatsViewController(context, peerId: peerId, datacenterId: datacenterId))
    }
    
    func report() -> Void {
        let context = self.context
        let peerId = self.peerId
        
        let report = reportReasonSelector(context: context) |> mapToSignal { reason -> Signal<Void, NoError> in
            return showModalProgress(signal: reportPeer(account: context.account, peerId: peerId, reason: reason), for: context.window)
        } |> deliverOnMainQueue
        
        reportPeerDisposable.set(report.start(next: { [weak self] in
            self?.pullNavigation()?.controller.show(toaster: ControllerToaster(text: L10n.peerInfoChannelReported))
        }))
    }
    
    func updateEditingDescriptionText(_ text:String) -> Void {
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(editingState.withUpdatedEditingDescriptionText(text))
            }
            return state
        }
    }
    
    func updateEditingName(_ name:String) -> Void {
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(ChannelInfoEditingState(editingName: name, editingDescriptionText: editingState.editingDescriptionText))
            } else {
                return state
            }
        }
    }
    private var _mediaController: PeerMediaController? = nil
    var mediaController: PeerMediaController {
        if _mediaController == nil {
            _mediaController = PeerMediaController(context: context, peerId: peerId, tagMask: [])
        }
        return _mediaController!
    }
    
    deinit {
        reportPeerDisposable.dispose()
        updatePeerNameDisposable.dispose()
        toggleSignaturesDisposable.dispose()
        updatePhotoDisposable.dispose()
        
        var mediaController = _mediaController
        _mediaController = nil
        if mediaController != nil {
            Queue.mainQueue().async {
                mediaController = nil
            }
        }
    }
}

enum ChannelInfoEntry: PeerInfoEntry {
    case info(sectionId: ChannelInfoSection, peerView: PeerView, editable:Bool, updatingPhotoState:PeerInfoUpdatingPhotoState?, viewType: GeneralViewType)
    case scam(sectionId: ChannelInfoSection, text: String, viewType: GeneralViewType)
    case about(sectionId: ChannelInfoSection, text: String, viewType: GeneralViewType)
    case userName(sectionId: ChannelInfoSection, value: String, viewType: GeneralViewType)
    case setPhoto(sectionId: ChannelInfoSection, viewType: GeneralViewType)
    case sharedMedia(sectionId: ChannelInfoSection, viewType: GeneralViewType)
    case notifications(sectionId: ChannelInfoSection, settings: PeerNotificationSettings?, viewType: GeneralViewType)
    case admins(sectionId: ChannelInfoSection, count:Int32?, viewType: GeneralViewType)
    case blocked(sectionId: ChannelInfoSection, count:Int32?, viewType: GeneralViewType)
    case members(sectionId: ChannelInfoSection, count:Int32?, viewType: GeneralViewType)
    case statistics(sectionId: ChannelInfoSection, datacenterId: Int32, viewType: GeneralViewType)
    case link(sectionId: ChannelInfoSection, addressName:String, viewType: GeneralViewType)
    case discussion(sectionId: ChannelInfoSection, group: Peer?, participantsCount: Int32?, viewType: GeneralViewType)
    case discussionDesc(sectionId: ChannelInfoSection, viewType: GeneralViewType)
    case aboutInput(sectionId: ChannelInfoSection, description:String, viewType: GeneralViewType)
    case aboutDesc(sectionId: ChannelInfoSection, viewType: GeneralViewType)
    case signMessages(sectionId: ChannelInfoSection, sign:Bool, viewType: GeneralViewType)
    case signDesc(sectionId: ChannelInfoSection, viewType: GeneralViewType)
    case report(sectionId: ChannelInfoSection, viewType: GeneralViewType)
    case leave(sectionId: ChannelInfoSection, isCreator: Bool, viewType: GeneralViewType)
    
    case media(sectionId: ChannelInfoSection, controller: PeerMediaController, viewType: GeneralViewType)
    case section(Int)
    
    func withUpdatedViewType(_ viewType: GeneralViewType) -> ChannelInfoEntry {
        switch self {
        case let .info(sectionId, peerView, editable, updatingPhotoState, _): return .info(sectionId: sectionId, peerView: peerView, editable: editable, updatingPhotoState: updatingPhotoState, viewType: viewType)
        case let .scam(sectionId, text, _): return .scam(sectionId: sectionId, text: text, viewType: viewType)
        case let .about(sectionId, text, _): return .about(sectionId: sectionId, text: text, viewType: viewType)
        case let .userName(sectionId, value, _): return .userName(sectionId: sectionId, value: value, viewType: viewType)
        case let .setPhoto(sectionId, _): return .setPhoto(sectionId: sectionId, viewType: viewType)
        case let .sharedMedia(sectionId, _): return .sharedMedia(sectionId: sectionId, viewType: viewType)
        case let .notifications(sectionId, settings, _): return .notifications(sectionId: sectionId, settings: settings, viewType: viewType)
        case let .admins(sectionId, count, _): return .admins(sectionId: sectionId, count: count, viewType: viewType)
        case let .blocked(sectionId, count, _): return .blocked(sectionId: sectionId, count: count, viewType: viewType)
        case let .members(sectionId, count, _): return .members(sectionId: sectionId, count: count, viewType: viewType)
        case let .statistics(sectionId, datacenterId, _): return .statistics(sectionId: sectionId, datacenterId: datacenterId, viewType: viewType)
        case let .link(sectionId, addressName, _): return .link(sectionId: sectionId, addressName: addressName, viewType: viewType)
        case let .discussion(sectionId, group, participantsCount, _): return .discussion(sectionId: sectionId, group: group, participantsCount: participantsCount, viewType: viewType)
        case let .discussionDesc(sectionId, _): return .discussionDesc(sectionId: sectionId, viewType: viewType)
        case let .aboutInput(sectionId, description, _): return .aboutInput(sectionId: sectionId, description: description, viewType: viewType)
        case let .aboutDesc(sectionId, _): return .aboutDesc(sectionId: sectionId, viewType: viewType)
        case let .signMessages(sectionId, sign, _): return .signMessages(sectionId: sectionId, sign: sign, viewType: viewType)
        case let .signDesc(sectionId, _): return .signDesc(sectionId: sectionId, viewType: viewType)
        case let .report(sectionId, _): return .report(sectionId: sectionId, viewType: viewType)
        case let .leave(sectionId, isCreator, _): return .leave(sectionId: sectionId, isCreator: isCreator, viewType: viewType)
        case let .media(sectionId, controller, _): return .media(sectionId: sectionId, controller: controller, viewType: viewType)
        case .section: return self
        }
    }
    
    var stableId: PeerInfoEntryStableId {
        return IntPeerInfoEntryStableId(value: self.stableIndex)
    }
    
    func isEqual(to: PeerInfoEntry) -> Bool {
        guard let entry = to as? ChannelInfoEntry else {
            return false
        }
        switch self {
        case let .info(sectionId, lhsPeerView, editable, updatingPhotoState, viewType):
            switch entry {
            case .info(sectionId, let rhsPeerView, editable, updatingPhotoState, viewType):
                
                let lhsPeer = peerViewMainPeer(lhsPeerView)
                let lhsCachedData = lhsPeerView.cachedData
                
                let rhsPeer = peerViewMainPeer(rhsPeerView)
                let rhsCachedData = rhsPeerView.cachedData
                
                if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                } else if (lhsPeer == nil) != (rhsPeer != nil) {
                    return false
                }
                if let lhsCachedData = lhsCachedData, let rhsCachedData = rhsCachedData {
                    if !lhsCachedData.isEqual(to: rhsCachedData) {
                        return false
                    }
                } else if (lhsCachedData == nil) != (rhsCachedData != nil) {
                    return false
                }
                return true
            default:
                return false
            }
        case  let .scam(sectionId, text, viewType):
            switch entry {
            case .scam(sectionId, text, viewType):
                return true
            default:
                return false
            }
        case  let .about(sectionId, text, viewType):
            switch entry {
            case .about(sectionId, text, viewType):
                return true
            default:
                return false
            }
        case let .userName(sectionId, value, viewType):
            switch entry {
            case .userName(sectionId, value, viewType):
                return true
            default:
                return false
            }
        case let .setPhoto(sectionId, viewType):
            switch entry {
            case .setPhoto(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .sharedMedia(sectionId, viewType):
            switch entry {
            case .sharedMedia(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .notifications(sectionId, lhsSettings, viewType):
            switch entry {
            case .notifications(sectionId, let rhsSettings, viewType):
                if let lhsSettings = lhsSettings, let rhsSettings = rhsSettings {
                    return lhsSettings.isEqual(to: rhsSettings)
                } else if (lhsSettings != nil) != (rhsSettings != nil) {
                    return false
                }
                return true
            default:
                return false
            }
        case let .report(sectionId, viewType):
            switch entry {
            case .report(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .admins(sectionId, count, viewType):
            if case .admins(sectionId, count, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .blocked(sectionId, count, viewType):
            if case .blocked(sectionId, count, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .members(sectionId, count, viewType):
            if case .members(sectionId, count, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .statistics(sectionId, datacenterId, viewType):
            if case .statistics(sectionId, datacenterId, viewType) = entry {
                return true
            } else {
                return false
            }
            
        case let .link(sectionId, addressName, viewType):
            if case .link(sectionId, addressName, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .discussion(sectionId, lhsGroup, participantsCount, viewType):
            if case .discussion(sectionId, let rhsGroup, participantsCount, viewType) = entry {
                if let lhsGroup = lhsGroup, let rhsGroup = rhsGroup {
                    return lhsGroup.isEqual(rhsGroup)
                } else if (lhsGroup != nil) != (rhsGroup != nil) {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .discussionDesc(sectionId, viewType):
            if case .discussionDesc(sectionId, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .aboutInput(sectionId, text, viewType):
            if case .aboutInput(sectionId, text, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .aboutDesc(sectionId, viewType):
            if case .aboutDesc(sectionId, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .signMessages(sectionId, sign, viewType):
            if case .signMessages(sectionId, sign, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .signDesc(sectionId, viewType):
            if case .signDesc(sectionId, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .leave(sectionId, isCreator, viewType):
            switch entry {
            case .leave(sectionId, isCreator, viewType):
                return true
            default:
                return false
            }
        case let .section(lhsId):
            switch entry {
            case let .section(rhsId):
                return lhsId == rhsId
            default:
                return false
            }
        case let .media(sectionId, _, viewType):
            switch entry {
            case .media(sectionId, _, viewType):
                return true
            default:
                return false
            }
        }
    }
    
    private var stableIndex: Int {
        switch self {
        case .info:
            return 0
        case .setPhoto:
            return 1
        case .scam:
            return 2
        case .about:
            return 3
        case .userName:
            return 4
        case .notifications:
            return 5
        case .sharedMedia:
            return 6
        case .statistics:
            return 7
        case .admins:
            return 8
        case .members:
            return 9
        case .blocked:
            return 10
        case .link:
            return 11
        case .discussion:
            return 12
        case .discussionDesc:
            return 13
        case .aboutInput:
            return 14
        case .aboutDesc:
            return 15
        case .signMessages:
            return 16
        case .signDesc:
            return 17
        case .report:
            return 18
        case .leave:
            return 19
        case .media:
            return 20
        case let .section(id):
            return (id + 1) * 1000 - id
        }
    }
    
    fileprivate var sectionId: Int {
        switch self {
        case let .info(sectionId, _, _, _, _):
            return sectionId.rawValue
        case let .setPhoto(sectionId, _):
            return sectionId.rawValue
        case let .scam(sectionId, _, _):
            return sectionId.rawValue
        case let .about(sectionId, _, _):
            return sectionId.rawValue
        case let .userName(sectionId, _, _):
            return sectionId.rawValue
        case let .sharedMedia(sectionId, _):
            return sectionId.rawValue
        case let .notifications(sectionId, _, _):
            return sectionId.rawValue
        case let .admins(sectionId, _, _):
            return sectionId.rawValue
        case let .blocked(sectionId, _, _):
            return sectionId.rawValue
        case let .members(sectionId, _, _):
            return sectionId.rawValue
        case let .statistics(sectionId, _, _):
            return sectionId.rawValue
        case let .link(sectionId, _, _):
            return sectionId.rawValue
        case let .discussion(sectionId, _, _, _):
            return sectionId.rawValue
        case let .discussionDesc(sectionId, _):
            return sectionId.rawValue
        case let .aboutInput(sectionId, _, _):
            return sectionId.rawValue
        case let .aboutDesc(sectionId, _):
            return sectionId.rawValue
        case let .signMessages(sectionId, _, _):
            return sectionId.rawValue
        case let .signDesc(sectionId, _):
            return sectionId.rawValue
        case let .report(sectionId, _):
            return sectionId.rawValue
        case let .leave(sectionId, _, _):
            return sectionId.rawValue
        case let .media(sectionId, _, _):
            return sectionId.rawValue
        case let .section(sectionId):
            return sectionId
        }
    }
    
    private var sortIndex: Int {
        switch self {
        case let .info(sectionId, _, _, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .setPhoto(sectionId, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .scam(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .about(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .userName(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .sharedMedia(sectionId, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .notifications(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .admins(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .blocked(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .members(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .statistics(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .link(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .discussion(sectionId, _, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .discussionDesc(sectionId, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .aboutInput(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .aboutDesc(sectionId, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .signMessages(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .signDesc(sectionId, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .report(sectionId, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .leave(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .media(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    func isOrderedBefore(_ entry: PeerInfoEntry) -> Bool {
        guard let entry = entry as? ChannelInfoEntry else {
            return false
        }
        return self.sortIndex < entry.sortIndex
    }
    
    func item(initialSize:NSSize, arguments:PeerInfoArguments) -> TableRowItem {
        let arguments = arguments as! ChannelInfoArguments
        let state = arguments.state as! ChannelInfoState
        switch self {
        case let .info(_, peerView, editable, updatingPhotoState, viewType):
            return PeerInfoHeaderItem(initialSize, stableId: stableId.hashValue, context: arguments.context, peerView:peerView, viewType: viewType, editable: editable, updatingPhotoState: updatingPhotoState, firstNameEditableText: state.editingState?.editingName, textChangeHandler: { name, _ in
                arguments.updateEditingName(name)
            })
        case let .scam(_, text, viewType):
            return TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: L10n.peerInfoScam, labelColor: theme.colors.redUI, text: text, context: arguments.context, viewType: viewType, detectLinks:false)
        case let .about(_, text, viewType):
            return TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: L10n.peerInfoInfo, text:text, context: arguments.context, viewType: viewType, detectLinks:true, openInfo: { peerId, toChat, postId, _ in
                if toChat {
                    arguments.peerChat(peerId, postId: postId)
                } else {
                    arguments.peerInfo(peerId)
                }
            }, hashtag: arguments.context.sharedContext.bindings.globalSearch)
        case let .userName(_, value, viewType):
            let link = "https://t.me/\(value)"
            return  TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: L10n.peerInfoSharelink, text: link, context: arguments.context, viewType: viewType, isTextSelectable:false, callback:{
                showModal(with: ShareModalController(ShareLinkObject(arguments.context, link: link)), for: arguments.context.window)
            }, selectFullWord: true)
        case let .sharedMedia(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSharedMedia, type: .next, viewType: viewType, action: { () in
                arguments.sharedMedia()
            })
        case let .notifications(_, settings, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoNotifications, type: .switchable(!((settings as? TelegramPeerNotificationSettings)?.isMuted ?? false)), viewType: viewType, action: {
               arguments.toggleNotifications()
            })
        case let .report(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoReport, type: .none, viewType: viewType, action: { () in
                arguments.report()
            })
        case let .members(_, count, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSubscribers, type: .nextContext(count != nil && count! > 0 ? "\(count!)" : ""), viewType: viewType, action: arguments.members)
        case let .admins(_, count, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoAdministrators, type: .nextContext(count != nil && count! > 0 ? "\(count!)" : ""), viewType: viewType, action: arguments.admins)
        case let .blocked(_, count, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoRemovedUsers, type: .nextContext(count != nil && count! > 0 ? "\(count!)" : ""), viewType: viewType, action: arguments.blocked)
        case let .statistics(_, datacenterId, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoStatistics, type: .next, viewType: viewType, action: {
                arguments.stats(datacenterId)
            })
        case let .link(_, addressName: addressName, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoChannelType, type: .context(addressName.isEmpty ? L10n.channelPrivate : L10n.channelPublic), viewType: viewType, action: arguments.visibilitySetup)
        case let .discussion(_, group, _, viewType):
            let title: String
            if let group = group {
                if let address = group.addressName {
                    title = "@\(address)"
                } else {
                    title = group.displayTitle
                }
            } else {
                title = L10n.peerInfoDiscussionAdd
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoDiscussion, type: .nextContext(title), viewType: viewType, action: arguments.setupDiscussion)
        case let .discussionDesc(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: L10n.peerInfoDiscussionDesc, viewType: viewType)
        case let .setPhoto(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSetChannelPhoto, nameStyle: blueActionButton, type: .none, viewType: viewType, action: {
                filePanel(with: photoExts, allowMultiple: false, canChooseDirectories: false, for: arguments.context.window, completion: { paths in
                    if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                        _ = (putToTemp(image: image, compress: false) |> deliverOnMainQueue).start(next: { path in
                            let controller = EditImageModalController(URL(fileURLWithPath: path), settings: .disableSizes(dimensions: .square))
                            showModal(with: controller, for: arguments.context.window, animationType: .scaleCenter)
                            _ = controller.result.start(next: { url, _ in
                                arguments.updatePhoto(url.path)
                            })
                            
                            controller.onClose = {
                                removeFile(at: path)
                            }
                        })
                    }
                })
            })
        case let .aboutInput(_, text, viewType):
            return InputDataRowItem(initialSize, stableId: stableId.hashValue, mode: .plain, error: nil, viewType: viewType, currentText: text, placeholder: nil, inputPlaceholder: L10n.peerInfoAboutPlaceholder, filter: { $0 }, updated: arguments.updateEditingDescriptionText, limit: 255)
        case let .aboutDesc(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: L10n.peerInfoSetAboutDescription, viewType: viewType)
        case let .signMessages(_, sign, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSignMessages, type: .switchable(sign), viewType: viewType, action: {
                arguments.toggleSignatures(!sign)
            })
        case let .signDesc(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: L10n.peerInfoSignMessagesDesc, viewType: viewType)
        case let .leave(_, isCreator, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: isCreator ? L10n.peerInfoDeleteChannel : L10n.peerInfoLeaveChannel, nameStyle:redActionButton, type: .none, viewType: viewType, action: arguments.delete)
        case let .media(_, controller, viewType):
            return PeerMediaBlockRowItem(initialSize, stableId: stableId.hashValue, controller: controller, viewType: viewType)
        case .section(_):
            return GeneralRowItem(initialSize, height:30, stableId: stableId.hashValue, viewType: .separator)
        }
    }
}

enum ChannelInfoSection : Int {
    case header = 1
    case desc = 2
    case info = 3
    case type = 4
    case sign = 5
    case manage = 6
    case addition = 7
    case destruct = 8
    case media = 9
}

func channelInfoEntries(view: PeerView, arguments:PeerInfoArguments) -> [PeerInfoEntry] {
    
    let arguments = arguments as! ChannelInfoArguments
    let state = arguments.state as! ChannelInfoState
    
    var entries: [ChannelInfoEntry] = []
    
    
    
    var infoBlock:[ChannelInfoEntry] = []
    
    
    func applyBlock(_ block:[ChannelInfoEntry]) {
        var block = block
        for (i, item) in block.enumerated() {
            block[i] = item.withUpdatedViewType(bestGeneralViewType(block, for: i))
        }
        entries.append(contentsOf: block)
    }
    
    infoBlock.append(.info(sectionId: .header, peerView: view, editable: state.editingState != nil, updatingPhotoState: state.updatingPhotoState, viewType: .singleItem))

    
    if let channel = peerViewMainPeer(view) as? TelegramChannel {
        
        if let editingState = state.editingState {
            if channel.hasPermission(.changeInfo) {
                infoBlock.append(.setPhoto(sectionId: .header, viewType: .singleItem))
            }
            
            applyBlock(infoBlock)
            
            if channel.hasPermission(.changeInfo) && !channel.isScam {
                entries.append(.aboutInput(sectionId: .desc, description: editingState.editingDescriptionText, viewType: .singleItem))
                entries.append(.aboutDesc(sectionId: .desc, viewType: .textBottomItem))
            }
            if channel.flags.contains(.isCreator) {
                entries.append(.link(sectionId: .type, addressName: channel.username ?? "", viewType: .firstItem))
                
                let group: Peer?
                if let cachedData = view.cachedData as? CachedChannelData, let linkedDiscussionPeerId = cachedData.linkedDiscussionPeerId {
                    group = view.peers[linkedDiscussionPeerId]
                } else {
                    group = nil
                }
                entries.append(.discussion(sectionId: .type, group: group, participantsCount: nil, viewType: .lastItem))
                entries.append(.discussionDesc(sectionId: .type, viewType: .textBottomItem))
            }
            
            
            let messagesShouldHaveSignatures:Bool
            switch channel.info {
            case let .broadcast(info):
                messagesShouldHaveSignatures = info.flags.contains(.messagesShouldHaveSignatures)
            default:
                messagesShouldHaveSignatures = false
            }
            
            if channel.hasPermission(.changeInfo) {
                entries.append(.signMessages(sectionId: .sign, sign: messagesShouldHaveSignatures, viewType: .singleItem))
                entries.append(.signDesc(sectionId: .sign, viewType: .textBottomItem))
            }
            

            entries.append(.leave(sectionId: .destruct, isCreator: channel.flags.contains(.isCreator), viewType: .singleItem))
            
        } else {
            
             applyBlock(infoBlock)
            
            
            
            
            var aboutBlock:[ChannelInfoEntry] = []
            if channel.isScam {
                aboutBlock.append(.scam(sectionId: .desc, text: L10n.channelInfoScamWarning, viewType: .singleItem))
            }
            if let cachedData = view.cachedData as? CachedChannelData {
                if let about = cachedData.about, !about.isEmpty, !channel.isScam {
                    aboutBlock.append(.about(sectionId: .desc, text: about, viewType: .singleItem))
                }
            }
            
            if let username = channel.username, !username.isEmpty {
                aboutBlock.append(.userName(sectionId: .desc, value: username, viewType: .singleItem))
            }
            
            applyBlock(aboutBlock)
            
            
            if channel.flags.contains(.isCreator) || (channel.adminRights != nil && !channel.adminRights!.isEmpty) {
                var membersCount:Int32? = nil
                var adminsCount:Int32? = nil
                var blockedCount:Int32? = nil
                var canViewStats: Bool = false
                
                
                if let cachedData = view.cachedData as? CachedChannelData {
                    membersCount = cachedData.participantsSummary.memberCount
                    adminsCount = cachedData.participantsSummary.adminCount
                    blockedCount = cachedData.participantsSummary.kickedCount
                    canViewStats = cachedData.flags.contains(.canViewStats)
                }
                entries.append(.admins(sectionId: .manage, count: adminsCount, viewType: .firstItem))
                entries.append(.members(sectionId: .manage, count: membersCount, viewType: .innerItem))
              
                entries.append(.blocked(sectionId: .manage, count: blockedCount, viewType: .lastItem))
                
            }
            
     
            var additionBlock:[ChannelInfoEntry] = []
            
            if !arguments.isAd {
                additionBlock.append(.notifications(sectionId: .addition, settings: view.notificationSettings, viewType: .singleItem))
            }
            additionBlock.append(.sharedMedia(sectionId: .addition, viewType: .singleItem))
            
            var datacenterId: Int32 = 0
            
            if let cachedData = view.cachedData as? CachedChannelData {
                datacenterId = cachedData.statsDatacenterId
            }
            
            if datacenterId > 0 {
                additionBlock.append(.statistics(sectionId: .addition, datacenterId: datacenterId, viewType: .innerItem))
            }
            
            applyBlock(additionBlock)
            
            var destructBlock:[ChannelInfoEntry] = []
            if !channel.flags.contains(.isCreator) {
                destructBlock.append(.report(sectionId: .destruct, viewType: .singleItem))
                if channel.participationStatus == .member {
                    destructBlock.append(.leave(sectionId: .destruct, isCreator: false, viewType: .singleItem))
                }
            }
            applyBlock(destructBlock)
        }
    }
    
    #if DEBUG
    entries.append(.media(sectionId: ChannelInfoSection.media, controller: arguments.mediaController, viewType: .singleItem))
    #endif
    
    var items:[ChannelInfoEntry] = []
    var sectionId:Int = 0
    for entry in entries {
        if entry.sectionId != sectionId {
            items.append(.section(sectionId))
            sectionId = entry.sectionId
        }
        items.append(entry)
    }
    sectionId += 1
    items.append(.section(sectionId))
    
    
   
    
    entries = items
    
    return entries.sorted(by: { (p1, p2) -> Bool in
        return p1.isOrderedBefore(p2)
    })
}
