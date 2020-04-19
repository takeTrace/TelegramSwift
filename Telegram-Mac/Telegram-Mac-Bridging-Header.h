//
//  Telegram-Mac-Bridging-Header.h
//  Telegram-Mac
//
//  Created by keepcoder on 19/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//



#ifndef Telegram_Mac_Bridging_Header_h
#define Telegram_Mac_Bridging_Header_h

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenGL/gl.h>
#import "MP4Atom.h"
#import "HackUtils.h"
#import "BuildConfig.h"
#import "TGModernGrowingTextView.h"


#ifndef SHARE
#import "ffmpeg/include/libavcodec/avcodec.h"
#import "ffmpeg/include/libavformat/avformat.h"
#import "libjpeg-turbo/jpeglib.h"
#import "libjpeg-turbo/jerror.h"
#import "libjpeg-turbo/turbojpeg.h"
#import "libjpeg-turbo/jmorecfg.h"
#import "FFMpegRemuxer.h"
#import "FFMpegGlobals.h"
#import "FFMpegAVFormatContext.h"
#import "FFMpegAVIOContext.h"
#import "FFMpegAVCodec.h"
#import "FFMpegAVCodecContext.h"
#import "FFMpegAVFrame.h"
#import "FFMpegPacket.h"
#import "FFMpegSwResample.h"
#import "GZip.h"
#import "Svg.h"
#endif

#import "CallBridge.h"
#import "CalendarUtils.h"
#import "RingBuffer.h"
#import "ocr.h"
#import "TGPassportMRZ.h"
#import "EDSunriseSet.h"
#import "ObjcUtils.h"


//#import <ChromiumTabs/ChromiumTabs.h>
//#include <Cocoa/Cocoa.h>
//#import <IOKit/hidsystem/ev_keymap.h>
//#import <Carbon/Carbon.h>





#if !__has_feature(nullability)
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#define nullable
#endif

void stickerThumbnailAlphaBlur(int imageWidth, int imageHeight, int imageStride, void * __nullable pixels);
void telegramFastBlurMore(int imageWidth, int imageHeight, int imageStride, void * __nullable pixels);
void telegramFastBlur(int imageWidth, int imageHeight, int imageStride, void * __nullable pixels);
int64_t SystemIdleTime(void);
NSDictionary<NSString * , NSString *> * __nonnull audioTags(AVURLAsset * __nonnull asset);
NSImage * __nonnull TGIdenticonImage(NSData * __nonnull data, NSData * __nonnull additionalData, CGSize size);

CGImageRef __nullable convertFromWebP(NSData *__nonnull data);





@interface NSWeakReference : NSObject

@property (nonatomic, weak) id __nullable value;

- (instancetype __nonnull)initWithValue:(id __nonnull)value;

@end

@interface OpusObjcBridge : NSObject

@end

@protocol OpusBridgeDelegate <NSObject>
- (void)audioPlayerDidFinishPlaying:(OpusObjcBridge * __nonnull)audioPlayer;
- (void)audioPlayerDidStartPlaying:(OpusObjcBridge * __nonnull)audioPlayer;
- (void)audioPlayerDidPause:(OpusObjcBridge * __nonnull)audioPlayer;
@end

@interface OpusObjcBridge ()

@property (nonatomic, weak) id<OpusBridgeDelegate> __nullable delegate;

+ (bool)canPlayFile:(NSString * __nonnull)path;
+ (NSTimeInterval)durationFile:(NSString * __nonnull)path;
- (instancetype __nonnull)initWithPath:(NSString * __nonnull)path;
- (void)play;
- (void)playFromPosition:(NSTimeInterval)position;
- (void)pause;
- (void)stop;
- (void)reset;
- (NSTimeInterval)currentPositionSync:(bool)sync;
- (NSTimeInterval)duration;
-(void)setCurrentPosition:(NSTimeInterval)position;
- (BOOL)isPaused;
- (BOOL)isEqualToPath:(NSString * __nonnull)path;
@end


//BEGIN AUDIO HEADER


@interface TGDataItem : NSObject

- (instancetype __nonnull)initWithFilePath:(NSString * __nonnull)filePath;

- (void)moveToPath:(NSString * __nonnull)path;
- (void)remove;

- (void)appendData:(NSData * __nonnull)data;
- (NSData * __nonnull)readDataAtOffset:(NSUInteger)offset length:(NSUInteger)length;
- (NSUInteger)length;

- (NSString * __nonnull)path;

@end

@interface TGAudioWaveform : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSData * __nonnull samples;
@property (nonatomic, readonly) int32_t peak;

- (instancetype __nonnull)initWithSamples:(NSData * __nonnull)samples peak:(int32_t)peak;
- (instancetype __nonnull)initWithBitstream:(NSData * __nonnull)bitstream bitsPerSample:(NSUInteger)bitsPerSample;

- (NSData * __nonnull)bitstream;
- (uint16_t * __nonnull)sampleList;
@end



double mappingRange(double x, double in_min, double in_max, double out_min, double out_max);


@interface TGOggOpusWriter : NSObject

- (bool)beginWithDataItem:(TGDataItem * __nonnull)dataItem;
- (bool)writeFrame:(uint8_t * __nullable)framePcmBytes frameByteCount:(NSUInteger)frameByteCount;
- (NSUInteger)encodedBytes;
- (NSTimeInterval)encodedDuration;

@end


@interface DateUtils : NSObject

+ (NSString * __nonnull)stringForShortTime:(int)time;
+ (NSString * __nonnull)stringForDialogTime:(int)time;
+ (NSString * __nonnull)stringForDayOfMonth:(int)date dayOfMonth:(int * __nonnull)dayOfMonth;
+ (NSString * __nonnull)stringForDayOfWeek:(int)date;
+ (NSString * __nonnull)stringForMessageListDate:(int)date;
+ (NSString * __nonnull)stringForLastSeen:(int)date;
+ (NSString * __nonnull)stringForLastSeenShort:(int)date;
+ (NSString * __nonnull)stringForRelativeLastSeen:(int)date;
+ (NSString * __nonnull)stringForUntil:(int)date;
+ (NSString * __nonnull)stringForDayOfMonthFull:(int)date dayOfMonth:(int * __nonnull)dayOfMonth;

+ (void)setDateLocalizationFunc:(NSString*  __nonnull (^__nonnull)(NSString * __nonnull key))localizationF;
@end

NSString * NSLocalized(NSString * key, NSString *comment);



NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, YTVimeoVideoThumbnailQuality) {
    YTVimeoVideoThumbnailQualitySmall  = 640,
    YTVimeoVideoThumbnailQualityMedium = 960,
    YTVimeoVideoThumbnailQualityHD     = 1280,
};

typedef NS_ENUM(NSUInteger, YTVimeoVideoQuality) {
    YTVimeoVideoQualityLow270    = 270,
    YTVimeoVideoQualityMedium360 = 360,
    YTVimeoVideoQualityMedium480 = 480,
    YTVimeoVideoQualityMedium540 = 540,
    YTVimeoVideoQualityHD720     = 720,
    YTVimeoVideoQualityHD1080    = 1080,
};



@interface YTVimeoVideo : NSObject <NSCopying>

@property (nonatomic, readonly) NSString *identifier;

@property (nonatomic, readonly) NSString *title;

@property (nonatomic, readonly) NSTimeInterval duration;


#if __has_feature(objc_generics)
@property (nonatomic, readonly) NSDictionary<id, NSURL *> *streamURLs;
#else
@property (nonatomic, readonly) NSDictionary *streamURLs;
#endif


#if __has_feature(objc_generics)
@property (nonatomic, readonly) NSDictionary<id, NSURL *> *__nullable thumbnailURLs;
#else
@property (nonatomic, readonly) NSDictionary *thumbnailURLs;
#endif


@property (nonatomic, readonly) NSDictionary *metaData;

-(NSURL * __nullable)highestQualityStreamURL;

-(NSURL * __nullable)lowestQualityStreamURL;

@property (nonatomic, readonly, nullable) NSURL *HTTPLiveStreamURL;

@end

@interface YTVimeoExtractor : NSObject

+(instancetype)sharedExtractor;

-(void)fetchVideoWithIdentifier:(NSString *)videoIdentifier withReferer:(NSString *__nullable)referer completionHandler:(void (^)(YTVimeoVideo * __nullable video, NSError * __nullable error))completionHandler;

-(void)fetchVideoWithVimeoURL:(NSString *)videoURL withReferer:(NSString *__nullable)referer completionHandler:(void (^)(YTVimeoVideo * __nullable video, NSError * __nullable error))completionHandler;

@end

typedef NS_ENUM(NSUInteger, XCDYouTubeVideoQuality) {
    XCDYouTubeVideoQualitySmall240  = 36,
    XCDYouTubeVideoQualityMedium360 = 18,
    XCDYouTubeVideoQualityHD720     = 22,
    XCDYouTubeVideoQualityHD1080 DEPRECATED_MSG_ATTRIBUTE("YouTube has removed 1080p mp4 videos.") = 37,
};

extern NSString *const XCDYouTubeVideoQualityHTTPLiveStreaming;

@interface XCDYouTubeVideo : NSObject <NSCopying>


@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly, nullable) NSURL *smallThumbnailURL;
@property (nonatomic, readonly, nullable) NSURL *mediumThumbnailURL;
@property (nonatomic, readonly, nullable) NSURL *largeThumbnailURL;
@property (nonatomic, readonly) NSDictionary<id, NSURL *> *streamURLs;
@property (nonatomic, readonly, nullable) NSDate *expirationDate;

@end

@protocol XCDYouTubeOperation <NSObject>

- (void) cancel;

@end

@interface XCDYouTubeClient : NSObject
+ (instancetype) defaultClient;
- (instancetype) initWithLanguageIdentifier:(nullable NSString *)languageIdentifier;
@property (nonatomic, readonly) NSString *languageIdentifier;
- (id<XCDYouTubeOperation>) getVideoWithIdentifier:(nullable NSString *)videoIdentifier completionHandler:(void (^)(XCDYouTubeVideo * __nullable video, NSError * __nullable error))completionHandler;

@end


//
//  SSKeychain.h
//  SSToolkit
//
//  Created by Sam Soffes on 5/19/10.
//  Copyright (c) 2009-2011 Sam Soffes. All rights reserved.
//


/** Error codes that can be returned in NSError objects. */
typedef enum {
    SSKeychainErrorNone = noErr,
    SSKeychainErrorBadArguments = -1001,
    SSKeychainErrorNoPassword = -1002,
    SSKeychainErrorInvalidParameter = errSecParam,
    SSKeychainErrorFailedToAllocated = errSecAllocate,
    SSKeychainErrorNotAvailable = errSecNotAvailable,
    SSKeychainErrorAuthorizationFailed = errSecAuthFailed,
    SSKeychainErrorDuplicatedItem = errSecDuplicateItem,
    SSKeychainErrorNotFound = errSecItemNotFound,
    SSKeychainErrorInteractionNotAllowed = errSecInteractionNotAllowed,
    SSKeychainErrorFailedToDecode = errSecDecode
} SSKeychainErrorCode;

extern NSString *const kSSKeychainErrorDomain;
extern NSString *const kSSKeychainAccountKey;
extern NSString *const kSSKeychainCreatedAtKey;
extern NSString *const kSSKeychainClassKey;
extern NSString *const kSSKeychainDescriptionKey;
extern NSString *const kSSKeychainLabelKey;
extern NSString *const kSSKeychainLastModifiedKey;
extern NSString *const kSSKeychainWhereKey;

@interface SSKeychain : NSObject

+ (NSArray *)allAccounts;
+ (NSArray *)allAccounts:(NSError **)error;
+ (NSArray *)accountsForService:(NSString *)serviceName;
+ (NSArray *)accountsForService:(NSString *)serviceName error:(NSError **)error;
+ (NSString *)passwordForService:(NSString *)serviceName account:(NSString *)account;
+ (NSString *)passwordForService:(NSString *)serviceName account:(NSString *)account error:(NSError **)error;
+ (NSData *  __nullable)passwordDataForService:(NSString *)serviceName account:(NSString *)account;
+ (NSData *  __nullable)passwordDataForService:(NSString *)serviceName account:(NSString *)account error:(NSError **)error;
+ (BOOL)deletePasswordForService:(NSString *)serviceName account:(NSString *)account;
+ (BOOL)deletePasswordForService:(NSString *)serviceName account:(NSString *)account error:(NSError **)error;
+ (BOOL)setPassword:(NSString *)password forService:(NSString *)serviceName account:(NSString *)account;
+ (BOOL)setPassword:(NSString *)password forService:(NSString *)serviceName account:(NSString *)account error:(NSError **)error;
+ (BOOL)setPasswordData:(NSData *)password forService:(NSString *)serviceName account:(NSString *)account;
+ (BOOL)setPasswordData:(NSData *)password forService:(NSString *)serviceName account:(NSString *)account error:(NSError **)error;

@end


@interface SPMediaKeyTap : NSObject
+ (NSArray*)defaultMediaKeyUserBundleIdentifiers;

-(id)initWithDelegate:(id)delegate;

+(BOOL)usesGlobalMediaKeyTap;
-(void)startWatchingMediaKeys;
-(void)stopWatchingMediaKeys;
-(void)handleAndReleaseMediaKeyEvent:(NSEvent *)event;
@end

@interface NSObject (SPMediaKeyTapDelegate)
-(void)mediaKeyTap:(SPMediaKeyTap*)keyTap receivedMediaKeyEvent:(NSEvent*)event;
@end

@interface TimeObserver : NSObject

void test_start_group(NSString * timeGroup);
void test_step_group(NSString *group);
void test_release_group(NSString *group);

@end

BOOL isEnterAccessObjc(NSEvent *theEvent, BOOL byCmdEnter);
BOOL isEnterEventObjc(NSEvent *theEvent);


@interface TGGifConverter : NSObject
+ (void)convertGifToMp4:(NSData *)data exportPath:(NSString *)exportPath completionHandler:(void (^)(NSString *path))completionHandler errorHandler:(dispatch_block_t)errorHandler cancelHandler:(BOOL (^)())cancelHandler;

+(NSSize)gifDimensionSize:(NSString *)path;
@end



@interface TGCurrencyFormatterEntry : NSObject

@property (nonatomic, strong, readonly) NSString *symbol;
@property (nonatomic, strong, readonly) NSString *thousandsSeparator;
@property (nonatomic, strong, readonly) NSString *decimalSeparator;
@property (nonatomic, readonly) bool symbolOnLeft;
@property (nonatomic, readonly) bool spaceBetweenAmountAndSymbol;
@property (nonatomic, readonly) int decimalDigits;

@end

@interface TGCurrencyFormatter : NSObject

+ (TGCurrencyFormatter *)shared;

- (NSString *)formatAmount:(int64_t)amount currency:(NSString *)currency;

@end


typedef NS_ENUM(int32_t, NumberPluralizationForm) {
    NumberPluralizationFormZero,
    NumberPluralizationFormOne,
    NumberPluralizationFormTwo,
    NumberPluralizationFormFew,
    NumberPluralizationFormMany,
    NumberPluralizationFormOther
};

NumberPluralizationForm numberPluralizationForm(unsigned int lc, int n);
unsigned int languageCodehash(NSString *code);
NS_ASSUME_NONNULL_END


@interface CEmojiSuggestion : NSObject
@property(nonatomic, strong) NSString * __nonnull emoji;
@property(nonatomic, strong) NSString * __nonnull label;
@property(nonatomic, strong) NSString * __nonnull replacement;
@end

@interface EmojiSuggestionBridge : NSObject
+(NSArray<CEmojiSuggestion *> * __nonnull)getSuggestions:(NSString * __nonnull)q;
@end

@interface TGVideoCameraGLRenderer : NSObject

@property (nonatomic, readonly) __attribute__((NSObject)) CMFormatDescriptionRef outputFormatDescription;
@property (nonatomic, assign) AVCaptureVideoOrientation orientation;
@property (nonatomic, assign) bool mirror;
@property (nonatomic, assign) CGFloat opacity;
@property (nonatomic, readonly) bool hasPreviousPixelbuffer;

- (void)prepareForInputWithFormatDescription:(CMFormatDescriptionRef)inputFormatDescription outputRetainedBufferCountHint:(size_t)outputRetainedBufferCountHint;
- (void)reset;

- (CVPixelBufferRef)copyRenderedPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)setPreviousPixelBuffer:(CVPixelBufferRef)previousPixelBuffer;

@end

@interface TGPaintShader : NSObject

@property (nonatomic, readonly) GLuint program;
@property (nonatomic, readonly) NSDictionary *uniforms;

- (instancetype)initWithVertexShader:(NSString *)vertexShader fragmentShader:(NSString *)fragmentShader attributes:(NSArray *)attributes uniforms:(NSArray *)uniforms;

- (GLuint)uniformForKey:(NSString *)key;

- (void)cleanResources;

@end


@protocol TGVideoCameraMovieRecorderDelegate;

@interface TGVideoCameraMovieRecorder : NSObject

@property (nonatomic, assign) bool paused;

- (instancetype __nonnull)initWithURL:(NSURL *)URL delegate:(id<TGVideoCameraMovieRecorderDelegate>)delegate callbackQueue:(dispatch_queue_t)queue;

- (void)addVideoTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription transform:(CGAffineTransform)transform settings:(NSDictionary *)videoSettings;
- (void)addAudioTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription settings:(NSDictionary *)audioSettings;


- (void)prepareToRecord;

- (void)appendVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer withPresentationTime:(CMTime)presentationTime;
- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)finishRecording;

- (NSTimeInterval)videoDuration;

@end

@protocol TGVideoCameraMovieRecorderDelegate <NSObject>
@required
- (void)movieRecorderDidFinishPreparing:(TGVideoCameraMovieRecorder *)recorder;
- (void)movieRecorder:(TGVideoCameraMovieRecorder *)recorder didFailWithError:(NSError *)error;
- (void)movieRecorderDidFinishRecording:(TGVideoCameraMovieRecorder *)recorder;
@end

typedef enum
{
    TGMediaVideoConversionPresetCompressedDefault,
    TGMediaVideoConversionPresetCompressedVeryLow,
    TGMediaVideoConversionPresetCompressedLow,
    TGMediaVideoConversionPresetCompressedMedium,
    TGMediaVideoConversionPresetCompressedHigh,
    TGMediaVideoConversionPresetCompressedVeryHigh,
    TGMediaVideoConversionPresetAnimation,
    TGMediaVideoConversionPresetVideoMessage
} TGMediaVideoConversionPreset;



@interface TGMediaVideoConversionPresetSettings : NSObject

+ (CGSize)maximumSizeForPreset:(TGMediaVideoConversionPreset)preset;
+ (NSDictionary *)videoSettingsForPreset:(TGMediaVideoConversionPreset)preset dimensions:(CGSize)dimensions;
+ (NSDictionary *)audioSettingsForPreset:(TGMediaVideoConversionPreset)preset;

@end


@class RHResizableImage;


typedef NSEdgeInsets RHEdgeInsets;


extern RHEdgeInsets RHEdgeInsetsMake(CGFloat top, CGFloat left, CGFloat bottom, CGFloat right);
extern CGRect RHEdgeInsetsInsetRect(CGRect rect, RHEdgeInsets insets, BOOL flipped); // If flipped origin is top-left otherwise origin is bottom-left (OSX Default is NO)
extern BOOL RHEdgeInsetsEqualToEdgeInsets(RHEdgeInsets insets1, RHEdgeInsets insets2);
extern const RHEdgeInsets RHEdgeInsetsZero;

extern NSString *NSStringFromRHEdgeInsets(RHEdgeInsets insets);
extern RHEdgeInsets RHEdgeInsetsFromString(NSString* string);


typedef NSImageResizingMode RHResizableImageResizingMode;
enum {
    RHResizableImageResizingModeTile = NSImageResizingModeTile,
    RHResizableImageResizingModeStretch = NSImageResizingModeStretch,
};



@interface NSImage (RHResizableImageAdditions)

-(RHResizableImage *)resizableImageWithCapInsets:(RHEdgeInsets)capInsets; // Create a resizable version of this image. the interior is tiled when drawn.
-(RHResizableImage *)resizableImageWithCapInsets:(RHEdgeInsets)capInsets resizingMode:(RHResizableImageResizingMode)resizingMode; // The interior is resized according to the resizingMode

-(RHResizableImage *)stretchableImageWithLeftCapWidth:(CGFloat)leftCapWidth topCapHeight:(CGFloat)topCapHeight; // Right cap is calculated as width - leftCapWidth - 1; bottom cap is calculated as height - topCapWidth - 1;


-(void)drawTiledInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(CGFloat)delta;
-(void)drawStretchedInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(CGFloat)delta;

@end



@interface RHResizableImage : NSImage <NSCopying> {
    // ivars are private
    RHEdgeInsets _capInsets;
    RHResizableImageResizingMode _resizingMode;
    
    NSArray *_imagePieces;
    
    NSBitmapImageRep *_cachedImageRep;
    NSSize _cachedImageSize;
    CGFloat _cachedImageDeviceScale;
}

-(id)initWithImage:(NSImage *)image leftCapWidth:(CGFloat)leftCapWidth topCapHeight:(CGFloat)topCapHeight; // right cap is calculated as width - leftCapWidth - 1; bottom cap is calculated as height - topCapWidth - 1;

-(id)initWithImage:(NSImage *)image capInsets:(RHEdgeInsets)capInsets;
-(id)initWithImage:(NSImage *)image capInsets:(RHEdgeInsets)capInsets resizingMode:(RHResizableImageResizingMode)resizingMode; // designated initializer

@property RHEdgeInsets capInsets; // Default is RHEdgeInsetsZero
@property RHResizableImageResizingMode resizingMode; // Default is UIImageResizingModeTile

-(void)drawInRect:(NSRect)rect;
-(void)drawInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(CGFloat)requestedAlpha;
-(void)drawInRect:(NSRect)rect operation:(NSCompositingOperation)op fraction:(CGFloat)requestedAlpha respectFlipped:(BOOL)respectContextIsFlipped hints:(NSDictionary *)hints;
-(void)drawInRect:(NSRect)rect fromRect:(NSRect)fromRect operation:(NSCompositingOperation)op fraction:(CGFloat)requestedAlpha respectFlipped:(BOOL)respectContextIsFlipped hints:(NSDictionary *)hints;

-(void)originalDrawInRect:(NSRect)rect fromRect:(NSRect)fromRect operation:(NSCompositingOperation)op fraction:(CGFloat)requestedAlpha respectFlipped:(BOOL)respectContextIsFlipped hints:(NSDictionary *)hints; //super passthrough


@end

// utilities
extern NSImage* RHImageByReferencingRectOfExistingImage(NSImage *image, NSRect rect);
extern NSArray* RHNinePartPiecesFromImageWithInsets(NSImage *image, RHEdgeInsets capInsets);
extern CGFloat RHContextGetDeviceScale(CGContextRef context);

// nine part
extern void RHDrawNinePartImage(NSRect frame, NSImage *topLeftCorner, NSImage *topEdgeFill, NSImage *topRightCorner, NSImage *leftEdgeFill, NSImage *centerFill, NSImage *rightEdgeFill, NSImage *bottomLeftCorner, NSImage *bottomEdgeFill, NSImage *bottomRightCorner, NSCompositingOperation op, CGFloat alphaFraction, BOOL shouldTile);

extern void RHDrawImageInRect(NSImage* image, NSRect rect, NSCompositingOperation op, CGFloat fraction, BOOL tile);
extern void RHDrawTiledImageInRect(NSImage* image, NSRect rect, NSCompositingOperation op, CGFloat fraction);
extern void RHDrawStretchedImageInRect(NSImage* image, NSRect rect, NSCompositingOperation op, CGFloat fraction);



#endif /* Telegram_Mac_Bridging_Header_h */
