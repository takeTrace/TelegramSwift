//
//  MediaResources.swift
//  Telegram
//
//  Created by keepcoder on 27/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

import Postbox
import TelegramCore
import SyncCore

public final class VideoMediaResourceAdjustments: PostboxCoding, Equatable {
    let data: MemoryBuffer
    let digest: MemoryBuffer
    
    init(data: MemoryBuffer, digest: MemoryBuffer) {
        self.data = data
        self.digest = digest
    }
    
    public init(decoder: PostboxDecoder) {
        self.data = decoder.decodeBytesForKey("d")!
        self.digest = decoder.decodeBytesForKey("h")!
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeBytes(self.data, forKey: "d")
        encoder.encodeBytes(self.digest, forKey: "h")
    }
    
    public static func ==(lhs: VideoMediaResourceAdjustments, rhs: VideoMediaResourceAdjustments) -> Bool {
        return lhs.data == rhs.data && lhs.digest == rhs.digest
    }
}

public struct VideoLibraryMediaResourceId: MediaResourceId {
    public let localIdentifier: String
    public let adjustmentsDigest: MemoryBuffer?
    
    public var uniqueId: String {
        if let adjustmentsDigest = self.adjustmentsDigest {
            return "vi-\(self.localIdentifier.replacingOccurrences(of: "/", with: "_"))-\(adjustmentsDigest.description)"
        } else {
            return "vi-\(self.localIdentifier.replacingOccurrences(of: "/", with: "_"))"
        }
    }
    
    public var hashValue: Int {
        return self.localIdentifier.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? VideoLibraryMediaResourceId {
            return self.localIdentifier == to.localIdentifier
        } else {
            return false
        }
    }
}

public final class VideoLibraryMediaResource: TelegramMediaResource {
    public let localIdentifier: String
    public let adjustments: VideoMediaResourceAdjustments?
    
    public var headerSize: Int32 {
        return 32 * 1024
    }
    
    public init(localIdentifier: String, adjustments: VideoMediaResourceAdjustments?) {
        self.localIdentifier = localIdentifier
        self.adjustments = adjustments
    }
    
    public required init(decoder: PostboxDecoder) {
        self.localIdentifier = decoder.decodeStringForKey("i", orElse: "")
        self.adjustments = decoder.decodeObjectForKey("a", decoder: { VideoMediaResourceAdjustments(decoder: $0) }) as? VideoMediaResourceAdjustments
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.localIdentifier, forKey: "i")
        if let adjustments = self.adjustments {
            encoder.encodeObject(adjustments, forKey: "a")
        } else {
            encoder.encodeNil(forKey: "a")
        }
    }
    
    public var id: MediaResourceId {
        return VideoLibraryMediaResourceId(localIdentifier: self.localIdentifier, adjustmentsDigest: self.adjustments?.digest)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? VideoLibraryMediaResource {
            return self.localIdentifier == to.localIdentifier && self.adjustments == to.adjustments
        } else {
            return false
        }
    }
}

public struct LocalFileGifMediaResourceId: MediaResourceId {
    public let randomId: Int64
    
    public var uniqueId: String {
        return "lgif-\(self.randomId)"
    }
    
    public var hashValue: Int {
        return self.randomId.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? LocalFileGifMediaResourceId {
            return self.randomId == to.randomId
        } else {
            return false
        }
    }
}



public final class LocalFileGifMediaResource: TelegramMediaResource {
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? LocalFileGifMediaResource {
            return self.randomId == to.randomId && self.path == to.path
        } else {
            return false
        }
    }
    
    public let randomId: Int64
    public let path: String
    
    public init(randomId: Int64, path: String) {
        self.randomId = randomId
        self.path = path
    }
    
    public required init(decoder: PostboxDecoder) {
        self.randomId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.path = decoder.decodeStringForKey("p", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.randomId, forKey: "i")
        encoder.encodeString(self.path, forKey: "p")
    }
    
    public var id: MediaResourceId {
        return LocalFileGifMediaResourceId(randomId: self.randomId)
    }
    
}

public struct LocalFileVideoMediaResourceId: MediaResourceId {
    public let randomId: Int64
    
    public var uniqueId: String {
        return "lmov-\(self.randomId)"
    }
    
    public var hashValue: Int {
        return self.randomId.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? LocalFileVideoMediaResourceId {
            return self.randomId == to.randomId
        } else {
            return false
        }
    }
}

public final class LocalFileVideoMediaResource: TelegramMediaResource {
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? LocalFileVideoMediaResource {
            return self.randomId == to.randomId && self.path == to.path
        } else {
            return false
        }
    }
    
    public let randomId: Int64
    public let path: String
    
    public init(randomId: Int64, path: String) {
        self.randomId = randomId
        self.path = path
    }
    
    public required init(decoder: PostboxDecoder) {
        self.randomId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.path = decoder.decodeStringForKey("p", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.randomId, forKey: "i")
        encoder.encodeString(self.path, forKey: "p")
    }
    
    public var id: MediaResourceId {
        return LocalFileVideoMediaResourceId(randomId: self.randomId)
    }
    
}

public struct LottieSoundMediaResourceId: MediaResourceId {
    public let randomId: Int64
    
    public var uniqueId: String {
        return "lottie-sound-\(self.randomId)"
    }
    
    public var hashValue: Int {
        return self.randomId.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? LottieSoundMediaResourceId {
            return self.randomId == to.randomId
        } else {
            return false
        }
    }
}

public final class LottieSoundMediaResource: TelegramMediaResource {
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? LottieSoundMediaResource {
            return self.randomId == to.randomId && self.data == to.data
        } else {
            return false
        }
    }
    
    public let randomId: Int64
    public let data: Data
    
    public init(randomId: Int64, data: Data) {
        self.randomId = randomId
        self.data = data
    }
    
    public required init(decoder: PostboxDecoder) {
        self.randomId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.data = decoder.decodeDataForKey("d") ?? Data()
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.randomId, forKey: "i")
        encoder.encodeData(self.data, forKey: "d")
    }
    
    public var id: MediaResourceId {
        return LottieSoundMediaResourceId(randomId: self.randomId)
    }
    
}



public struct LocalFileArchiveMediaResourceId: MediaResourceId {
    public let randomId: Int64
    
    public var uniqueId: String {
        return "larchive-\(self.randomId)"
    }
    
    public var hashValue: Int {
        return self.randomId.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? LocalFileArchiveMediaResourceId {
            return self.randomId == to.randomId
        } else {
            return false
        }
    }
}

public final class LocalFileArchiveMediaResource: TelegramMediaResource {
    public let randomId: Int64
    public let path: String
    
    public var headerSize: Int32 {
        return 32 * 1024
    }
    
    public init(randomId: Int64, path: String) {
        self.randomId = randomId
        self.path = path
    }
    
    public required init(decoder: PostboxDecoder) {
        self.randomId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.path = decoder.decodeStringForKey("p", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.randomId, forKey: "i")
        encoder.encodeString(self.path, forKey: "p")
    }
    
    public var id: MediaResourceId {
        return LocalFileArchiveMediaResourceId(randomId: self.randomId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? LocalFileArchiveMediaResource {
            return self.randomId == to.randomId && self.path == to.path
        } else {
            return false
        }
    }
}


public struct ExternalMusicAlbumArtResourceId: MediaResourceId {
    public let title: String
    public let performer: String
    public let isThumbnail: Bool
    
    public var uniqueId: String {
        return "ext-album-art-\(isThumbnail ? "thump" : "full")-\(self.title.replacingOccurrences(of: "/", with: "_"))-\(self.performer.replacingOccurrences(of: "/", with: "_"))"
    }
    
    public var hashValue: Int {
        return self.title.hashValue &* 31 &+ self.performer.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? ExternalMusicAlbumArtResourceId {
            return self.title == to.title && self.performer == to.performer && self.isThumbnail == to.isThumbnail
        } else {
            return false
        }
    }
}


public class ExternalMusicAlbumArtResource: TelegramMediaResource {
    public let title: String
    public let performer: String
    public let isThumbnail: Bool
    
    public init(title: String, performer: String, isThumbnail: Bool) {
        self.title = title
        self.performer = performer
        self.isThumbnail = isThumbnail
    }
    
    public required init(decoder: PostboxDecoder) {
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.performer = decoder.decodeStringForKey("p", orElse: "")
        self.isThumbnail = decoder.decodeInt32ForKey("th", orElse: 1) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeString(self.performer, forKey: "p")
        encoder.encodeInt32(self.isThumbnail ? 1 : 0, forKey: "th")
    }
    
    public var id: MediaResourceId {
        return ExternalMusicAlbumArtResourceId(title: self.title, performer: self.performer, isThumbnail: self.isThumbnail)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? ExternalMusicAlbumArtResource {
            return self.title == to.title && self.performer == to.performer && self.isThumbnail == to.isThumbnail
        } else {
            return false
        }
    }
}


public struct LocalBundleResourceId: MediaResourceId {
    public let name: String
    public let ext: String
    
    public var uniqueId: String {
        return "local-bundle-\(self.name)-\(self.ext)"
    }
    
    public var hashValue: Int {
        return self.name.hashValue
    }
    
    public func isEqual(to: MediaResourceId) -> Bool {
        if let to = to as? LocalBundleResourceId {
            return self.name == to.name && self.ext == to.ext
        } else {
            return false
        }
    }
}

public class LocalBundleResource: TelegramMediaResource {
    public let name: String
    public let ext: String
    
    public init(name: String, ext: String) {
        self.name = name
        self.ext = ext
    }
    
    public required init(decoder: PostboxDecoder) {
        self.name = decoder.decodeStringForKey("n", orElse: "")
        self.ext = decoder.decodeStringForKey("e", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.name, forKey: "n")
        encoder.encodeString(self.ext, forKey: "e")
    }
    
    public var id: MediaResourceId {
        return LocalBundleResourceId(name: self.name, ext: self.ext)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? LocalBundleResource {
            return self.name == to.name && self.ext == to.ext
        } else {
            return false
        }
    }
}
