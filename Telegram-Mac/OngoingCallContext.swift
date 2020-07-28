//
//  OngoingCallContext.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/06/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import Foundation
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox



private func callConnectionDescription(_ connection: CallSessionConnection) -> OngoingCallConnectionDescription {
    return OngoingCallConnectionDescription(connectionId: connection.id, ip: connection.ip, ipv6: connection.ipv6, port: connection.port, peerTag: connection.peerTag)
}

private func callConnectionDescriptionWebrtc(_ connection: CallSessionConnection) -> OngoingCallConnectionDescriptionWebrtc {
    return OngoingCallConnectionDescriptionWebrtc(connectionId: connection.id, ip: connection.ip, ipv6: connection.ipv6, port: connection.port, peerTag: connection.peerTag)
}

/*private func callConnectionDescriptionWebrtcCustom(_ connection: CallSessionConnection) -> OngoingCallConnectionDescriptionWebrtcCustom {
 return OngoingCallConnectionDescriptionWebrtcCustom(connectionId: connection.id, ip: connection.ip, ipv6: connection.ipv6, port: connection.port, peerTag: connection.peerTag)
 }*/

private let callLogsLimit = 20

public func callLogNameForId(id: Int64, account: Account) -> String? {
    let path = callLogsPath(account: account)
    let namePrefix = "\(id)_"
    
    if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
        for url in enumerator {
            if let url = url as? URL {
                if url.lastPathComponent.hasPrefix(namePrefix) {
                    return url.lastPathComponent
                }
            }
        }
    }
    return nil
}

public func callLogsPath(account: Account) -> String {
    return account.basePath + "/calls"
}

private func cleanupCallLogs(account: Account) {
    let path = callLogsPath(account: account)
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path, isDirectory: nil) {
        try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
    }
    
    var oldest: (URL, Date)? = nil
    var count = 0
    if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: nil) {
        for url in enumerator {
            if let url = url as? URL {
                if let date = (try? url.resourceValues(forKeys: Set([.contentModificationDateKey])))?.contentModificationDate {
                    if let currentOldest = oldest {
                        if date < currentOldest.1 {
                            oldest = (url, date)
                        }
                    } else {
                        oldest = (url, date)
                    }
                    count += 1
                }
            }
        }
    }
    if count > callLogsLimit, let oldest = oldest {
        try? fileManager.removeItem(atPath: oldest.0.path)
    }
}

private let setupLogs: Bool = {
    OngoingCallThreadLocalContext.setupLoggingFunction({ value in
        if let value = value {
            Logger.shared.log("TGVOIP", value)
        }
    })
    OngoingCallThreadLocalContextWebrtc.setupLoggingFunction({ value in
        if let value = value {
            Logger.shared.log("TGVOIP", value)
        }
    })
    /*OngoingCallThreadLocalContextWebrtcCustom.setupLoggingFunction({ value in
     if let value = value {
     Logger.shared.log("TGVOIP", value)
     }
     })*/
    return true
}()

public struct OngoingCallContextState: Equatable {
    public enum State {
        case initializing
        case connected
        case reconnecting
        case failed
    }
    
    public enum VideoState: Equatable {
        case notAvailable
        case available(Bool)
        case active
        case activeOutgoing
    }
    
    public enum RemoteVideoState: Equatable {
        case inactive
        case active
    }
    
    public let state: State
    public let videoState: VideoState
    public let remoteVideoState: RemoteVideoState
}

private final class OngoingCallThreadLocalContextQueueImpl: NSObject, OngoingCallThreadLocalContextQueue, OngoingCallThreadLocalContextQueueWebrtc /*, OngoingCallThreadLocalContextQueueWebrtcCustom*/ {
    private let queue: Queue
    
    init(queue: Queue) {
        self.queue = queue
        
        super.init()
    }
    
    func dispatch(_ f: @escaping () -> Void) {
        self.queue.async {
            f()
        }
    }
    
    func dispatch(after seconds: Double, block f: @escaping () -> Void) {
        self.queue.after(seconds, f)
    }
    
    func isCurrent() -> Bool {
        return self.queue.isCurrent()
    }
}

private func ongoingNetworkTypeForType(_ type: NetworkType) -> OngoingCallNetworkType {
    switch type {
    case .none:
        return .wifi
    case .wifi:
        return .wifi
    }
}

private func ongoingNetworkTypeForTypeWebrtc(_ type: NetworkType) -> OngoingCallNetworkTypeWebrtc {
    switch type {
    case .none:
        return .wifiWebrtc
    case .wifi:
        return .wifiWebrtc
    }
}

/*private func ongoingNetworkTypeForTypeWebrtcCustom(_ type: NetworkType) -> OngoingCallNetworkTypeWebrtcCustom {
 switch type {
 case .none:
 return .wifi
 case .wifi:
 return .wifi
 case let .cellular(cellular):
 switch cellular {
 case .edge:
 return .cellularEdge
 case .gprs:
 return .cellularGprs
 case .thirdG, .unknown:
 return .cellular3g
 case .lte:
 return .cellularLte
 }
 }
 }*/

private func ongoingDataSavingForType(_ type: VoiceCallDataSaving) -> OngoingCallDataSaving {
    switch type {
    case .never:
        return .never
    case .cellular:
        return .cellular
    case .always:
        return .always
    default:
        return .never
    }
}

private func ongoingDataSavingForTypeWebrtc(_ type: VoiceCallDataSaving) -> OngoingCallDataSavingWebrtc {
    switch type {
    case .never:
        return .neverWebrtc
    case .cellular:
        return .cellularWebrtc
    case .always:
        return .alwaysWebrtc
    default:
        return .neverWebrtc
    }
}

/*private func ongoingDataSavingForTypeWebrtcCustom(_ type: VoiceCallDataSaving) -> OngoingCallDataSavingWebrtcCustom {
 switch type {
 case .never:
 return .never
 case .cellular:
 return .cellular
 case .always:
 return .always
 default:
 return .never
 }
 }*/

private protocol OngoingCallThreadLocalContextProtocol: class {
    func nativeSetNetworkType(_ type: NetworkType)
    func nativeSetIsMuted(_ value: Bool)
    func nativeSetVideoEnabled(_ value: Bool)
    func nativeSwitchVideoCamera()
    func nativeStop(_ completion: @escaping (String?, Int64, Int64, Int64, Int64) -> Void)
    func nativeDebugInfo() -> String
    func nativeVersion() -> String
    func nativeGetDerivedState() -> Data
}

private final class OngoingCallThreadLocalContextHolder {
    let context: OngoingCallThreadLocalContextProtocol
    
    init(_ context: OngoingCallThreadLocalContextProtocol) {
        self.context = context
    }
}

extension OngoingCallThreadLocalContext: OngoingCallThreadLocalContextProtocol {
    func nativeSetNetworkType(_ type: NetworkType) {
        self.setNetworkType(ongoingNetworkTypeForType(type))
    }
    
    func nativeStop(_ completion: @escaping (String?, Int64, Int64, Int64, Int64) -> Void) {
        self.stop(completion)
    }
    
    func nativeSetIsMuted(_ value: Bool) {
        self.setIsMuted(value)
    }
    
    func nativeSetVideoEnabled(_ value: Bool) {
    }
    
    func nativeSwitchVideoCamera() {
    }
    
    func nativeDebugInfo() -> String {
        return self.debugInfo() ?? ""
    }
    
    func nativeVersion() -> String {
        return self.version() ?? ""
    }
    
    func nativeGetDerivedState() -> Data {
        return self.getDerivedState()
    }
}

extension OngoingCallThreadLocalContextWebrtc: OngoingCallThreadLocalContextProtocol {
    func nativeSetNetworkType(_ type: NetworkType) {
        self.setNetworkType(ongoingNetworkTypeForTypeWebrtc(type))
    }
    
    func nativeStop(_ completion: @escaping (String?, Int64, Int64, Int64, Int64) -> Void) {
        self.stop(completion)
    }
    
    func nativeSetIsMuted(_ value: Bool) {
        self.setIsMuted(value)
    }
    
    func nativeSetVideoEnabled(_ value: Bool) {
        self.setVideoEnabled(value)
    }
    
    func nativeSwitchVideoCamera() {
        self.switchVideoCamera()
    }
    
    func nativeDebugInfo() -> String {
        return self.debugInfo() ?? ""
    }
    
    func nativeVersion() -> String {
        return self.version() ?? ""
    }
    
    func nativeGetDerivedState() -> Data {
        return self.getDerivedState()
    }
}

/*extension OngoingCallThreadLocalContextWebrtcCustom: OngoingCallThreadLocalContextProtocol {
 func nativeSetNetworkType(_ type: NetworkType) {
 self.setNetworkType(ongoingNetworkTypeForTypeWebrtcCustom(type))
 }
 
 func nativeStop(_ completion: @escaping (String?, Int64, Int64, Int64, Int64) -> Void) {
 self.stop(completion)
 }
 
 func nativeSetIsMuted(_ value: Bool) {
 self.setIsMuted(value)
 }
 
 func nativeDebugInfo() -> String {
 return self.debugInfo() ?? ""
 }
 
 func nativeVersion() -> String {
 return self.version() ?? ""
 }
 
 func nativeGetDerivedState() -> Data {
 return self.getDerivedState()
 }
 }*/

private extension OngoingCallContextState.State {
    init(_ state: OngoingCallState) {
        switch state {
        case .initializing:
            self = .initializing
        case .connected:
            self = .connected
        case .failed:
            self = .failed
        case .reconnecting:
            self = .reconnecting
        default:
            self = .failed
        }
    }
}

private extension OngoingCallContextState.State {
    init(_ state: OngoingCallStateWebrtc) {
        switch state {
        case .initializingWebrtc:
            self = .initializing
        case .connectedWebrtc:
            self = .connected
        case .failedWebrtc:
            self = .failed
        case .reconnectingWebrtc:
            self = .reconnecting
        default:
            self = .failed
        }
    }
}

/*private extension OngoingCallContextState {
 init(_ state: OngoingCallStateWebrtcCustom) {
 switch state {
 case .initializing:
 self = .initializing
 case .connected:
 self = .connected
 case .failed:
 self = .failed
 case .reconnecting:
 self = .reconnecting
 default:
 self = .failed
 }
 }
 }*/

public final class OngoingCallContext {
    public struct AuxiliaryServer {
        public enum Connection {
            case stun
            case turn(username: String, password: String)
        }
        
        public let host: String
        public let port: Int
        public let connection: Connection
        
        public init(
            host: String,
            port: Int,
            connection: Connection
            ) {
            self.host = host
            self.port = port
            self.connection = connection
        }
    }
    
    public let internalId: CallSessionInternalId
    
    private let queue = Queue()
    private let account: Account
    private let callSessionManager: CallSessionManager
    private let logPath: String
    
    private var contextRef: Unmanaged<OngoingCallThreadLocalContextHolder>?
    
    private let contextState = Promise<OngoingCallContextState?>(nil)
    public var state: Signal<OngoingCallContextState?, NoError> {
        return self.contextState.get()
    }
    
    private var signalingDataDisposable: Disposable?
    
    private let receptionPromise = Promise<Int32?>(nil)
    public var reception: Signal<Int32?, NoError> {
        return self.receptionPromise.get()
    }
    
    private let audioSessionDisposable = MetaDisposable()
    private var networkTypeDisposable: Disposable?
    
    public static var maxLayer: Int32 {
        return OngoingCallThreadLocalContext.maxLayer()
        //return max(OngoingCallThreadLocalContext.maxLayer(), OngoingCallThreadLocalContextWebrtc.maxLayer())
    }
    
    public static func versions(includeExperimental: Bool) -> [String] {
        var result: [String] = [OngoingCallThreadLocalContext.version()]
        if includeExperimental {
            result.append(OngoingCallThreadLocalContextWebrtc.version())
            //result.append(OngoingCallThreadLocalContextWebrtcCustom.version())
        }
        return result
    }
    
    public init(account: Account, callSessionManager: CallSessionManager, internalId: CallSessionInternalId, proxyServer: ProxyServerSettings?, auxiliaryServers: [AuxiliaryServer], initialNetworkType: NetworkType, updatedNetworkType: Signal<NetworkType, NoError>, serializedData: String?, dataSaving: VoiceCallDataSaving, derivedState: VoipDerivedState, key: Data, isOutgoing: Bool, isVideo: Bool, connections: CallSessionConnectionSet, maxLayer: Int32, version: String, allowP2P: Bool, logName: String) {
        let _ = setupLogs
        OngoingCallThreadLocalContext.applyServerConfig(serializedData)
        //OngoingCallThreadLocalContextWebrtc.applyServerConfig(serializedData)
        
        self.internalId = internalId
        self.account = account
        self.callSessionManager = callSessionManager
        self.logPath = logName.isEmpty ? "" : callLogsPath(account: self.account) + "/" + logName + ".log"
        let logPath = self.logPath
        
        let queue = self.queue
        
        cleanupCallLogs(account: account)
        queue.sync {
            //version == OngoingCallThreadLocalContextWebrtc.version()
            if false {
                var voipProxyServer: VoipProxyServerWebrtc?
                if let proxyServer = proxyServer {
                    switch proxyServer.connection {
                    case let .socks5(username, password):
                        voipProxyServer = VoipProxyServerWebrtc(host: proxyServer.host, port: proxyServer.port, username: username, password: password)
                    case .mtp:
                        break
                    }
                }
                var rtcServers: [VoipRtcServerWebrtc] = []
                for server in auxiliaryServers {
                    switch server.connection {
                    case .stun:
                        rtcServers.append(VoipRtcServerWebrtc(
                            host: server.host,
                            port: Int32(clamping: server.port),
                            username: "",
                            password: "",
                            isTurn: false
                        ))
                    case let .turn(username, password):
                        rtcServers.append(VoipRtcServerWebrtc(
                            host: server.host,
                            port: Int32(clamping: server.port),
                            username: username,
                            password: password,
                            isTurn: false
                        ))
                    }
                }
                let context = OngoingCallThreadLocalContextWebrtc(queue: OngoingCallThreadLocalContextQueueImpl(queue: queue), proxy: voipProxyServer, rtcServers: rtcServers, networkType: ongoingNetworkTypeForTypeWebrtc(initialNetworkType), dataSaving: ongoingDataSavingForTypeWebrtc(dataSaving), derivedState: derivedState.data, key: key, isOutgoing: isOutgoing, isVideo: isVideo, primaryConnection: callConnectionDescriptionWebrtc(connections.primary), alternativeConnections: connections.alternatives.map(callConnectionDescriptionWebrtc), maxLayer: maxLayer, allowP2P: allowP2P, logPath: logPath, sendSignalingData: { [weak callSessionManager] data in
                    callSessionManager?.sendSignalingData(internalId: internalId, data: data)
                })
                
                self.contextRef = Unmanaged.passRetained(OngoingCallThreadLocalContextHolder(context))
                context.stateChanged = { [weak self] state, videoState, remoteVideoState in
                    queue.async {
                        guard let strongSelf = self else {
                            return
                        }
                        let mappedState = OngoingCallContextState.State(state)
                        let mappedVideoState: OngoingCallContextState.VideoState
                        switch videoState {
                        case .inactiveWebrtc:
                            mappedVideoState = .available(true)
                        case .activeWebrtc:
                            mappedVideoState = .active
                        case .activeOutgoingWebrtc:
                            mappedVideoState = .activeOutgoing
                        @unknown default:
                            mappedVideoState = .available(false)
                        }
                        let mappedRemoteVideoState: OngoingCallContextState.RemoteVideoState
                        switch remoteVideoState {
                        case .inactiveWebrtc:
                            mappedRemoteVideoState = .inactive
                        case .activeWebrtc:
                            mappedRemoteVideoState = .active
                        @unknown default:
                            mappedRemoteVideoState = .inactive
                        }
                        strongSelf.contextState.set(.single(OngoingCallContextState(state: mappedState, videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState)))
                    }
                }
                context.signalBarsChanged = { [weak self] signalBars in
                    self?.receptionPromise.set(.single(signalBars))
                }
                
                self.networkTypeDisposable = (updatedNetworkType
                    |> deliverOn(queue)).start(next: { [weak self] networkType in
                        self?.withContext { context in
                            context.nativeSetNetworkType(networkType)
                        }
                    })
            } else {
                var voipProxyServer: VoipProxyServer?
                if let proxyServer = proxyServer {
                    switch proxyServer.connection {
                    case let .socks5(username, password):
                        voipProxyServer = VoipProxyServer(host: proxyServer.host, port: proxyServer.port, username: username, password: password)
                    case .mtp:
                        break
                    }
                }
                let context = OngoingCallThreadLocalContext(queue: OngoingCallThreadLocalContextQueueImpl(queue: queue), proxy: voipProxyServer, networkType: ongoingNetworkTypeForType(initialNetworkType), dataSaving: ongoingDataSavingForType(dataSaving), derivedState: derivedState.data, key: key, isOutgoing: isOutgoing, primaryConnection: callConnectionDescription(connections.primary), alternativeConnections: connections.alternatives.map(callConnectionDescription), maxLayer: maxLayer, allowP2P: allowP2P, logPath: logPath)
                
                self.contextRef = Unmanaged.passRetained(OngoingCallThreadLocalContextHolder(context))
                context.stateChanged = { [weak self] state in
                    self?.contextState.set(.single(OngoingCallContextState(state: OngoingCallContextState.State(state), videoState: .notAvailable, remoteVideoState: .inactive)))
                }
                context.signalBarsChanged = { [weak self] signalBars in
                    self?.receptionPromise.set(.single(signalBars))
                }
                
                self.networkTypeDisposable = (updatedNetworkType
                |> deliverOn(queue)).start(next: { [weak self] networkType in
                    self?.withContext { context in
                        context.nativeSetNetworkType(networkType)
                    }
                })
            }
        }
        
        
        self.signalingDataDisposable = (callSessionManager.callSignalingData(internalId: internalId)).start(next: { [weak self] data in
            print("data received")
            queue.async {
                self?.withContext { context in
                    if let context = context as? OngoingCallThreadLocalContextWebrtc {
                        context.addSignaling(data)
                    }
                }
            }
        })
    }
    
    deinit {
        let contextRef = self.contextRef
        self.queue.async {
            contextRef?.release()
        }
        
        self.audioSessionDisposable.dispose()
        self.networkTypeDisposable?.dispose()
    }
    
    private func withContext(_ f: @escaping (OngoingCallThreadLocalContextProtocol) -> Void) {
        self.queue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                f(context.context)
            }
        }
    }
    
    public func stop(callId: CallId? = nil, sendDebugLogs: Bool = false, debugLogValue: Promise<String?>) {
        let account = self.account
        let logPath = self.logPath
        
        self.withContext { context in
            context.nativeStop { debugLog, bytesSentWifi, bytesReceivedWifi, bytesSentMobile, bytesReceivedMobile in
                debugLogValue.set(.single(debugLog))
                let delta = NetworkUsageStatsConnectionsEntry(
                    cellular: NetworkUsageStatsDirectionsEntry(
                        incoming: bytesReceivedMobile,
                        outgoing: bytesSentMobile),
                    wifi: NetworkUsageStatsDirectionsEntry(
                        incoming: bytesReceivedWifi,
                        outgoing: bytesSentWifi))
                updateAccountNetworkUsageStats(account: self.account, category: .call, delta: delta)
                
                if !logPath.isEmpty, let debugLog = debugLog {
                    let logsPath = callLogsPath(account: account)
                    let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
                    if let data = debugLog.data(using: .utf8) {
                        let _ = try? data.write(to: URL(fileURLWithPath: logPath))
                    }
                }
                
                if let callId = callId, let debugLog = debugLog {
                    if sendDebugLogs {
                        let _ = saveCallDebugLog(network: self.account.network, callId: callId, log: debugLog).start()
                    }
                }
            }
            let derivedState = context.nativeGetDerivedState()
            let _ = updateVoipDerivedStateInteractively(postbox: self.account.postbox, { _ in
                return VoipDerivedState(data: derivedState)
            }).start()
        }
    }
    
    public func setIsMuted(_ value: Bool) {
        self.withContext { context in
            context.nativeSetIsMuted(value)
        }
    }
    
    public func setEnableVideo(_ value: Bool) {
        self.withContext { context in
            context.nativeSetVideoEnabled(value)
        }
    }
    
    public func switchVideoCamera() {
        self.withContext { context in
            context.nativeSwitchVideoCamera()
        }
    }
    
    public func debugInfo() -> Signal<(String, String), NoError> {
        let poll = Signal<(String, String), NoError> { subscriber in
            self.withContext { context in
                let version = context.nativeVersion()
                let debugInfo = context.nativeDebugInfo()
                subscriber.putNext((version, debugInfo))
                subscriber.putCompletion()
            }
            
            return EmptyDisposable
        }
        return (poll |> then(.complete() |> delay(0.5, queue: Queue.concurrentDefaultQueue()))) |> restart
    }
    
    public func makeIncomingVideoView(completion: @escaping (NSView?) -> Void) {
        self.withContext { context in
            if let context = context as? OngoingCallThreadLocalContextWebrtc {
                context.makeIncomingVideoView(completion)
            } else {
                completion(nil)
            }
        }
    }
    
    public func makeOutgoingVideoView(completion: @escaping (NSView?) -> Void) {
        self.withContext { context in
            if let context = context as? OngoingCallThreadLocalContextWebrtc {
                context.makeOutgoingVideoView(completion)
            } else {
                completion(nil)
            }
        }
    }
}
