//
//  CallsBridge.m
//  Telegram
//
//  Created by keepcoder on 03/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

#import "CallBridge.h"
#import "VoIPController.h"
#import "VoIPServerConfig.h"
#import "TGCallUtils.h"
#import "TGCallConnectionDescription.h"
#define CVoIPController tgvoip::VoIPController

@implementation CProxy
-(id)initWithHost:(NSString*)host port:(int32_t)port user:(NSString *)user pass:(NSString *)pass {
    self = [super init];
    _host = host;
    _port = port;
    _user = user;
    _pass = pass;
    return self;
}
@end

@interface VoIPControllerHolder : NSObject {
    tgvoip::VoIPController *_controller;
}

@property (nonatomic, assign, readonly)  tgvoip::VoIPController *controller;

@end

@implementation AudioDevice
-(id)initWithDeviceId:(NSString *)deviceId deviceName:(NSString *)deviceName {
    if (self = [super init]) {
        _deviceId = deviceId;
        _deviceName = deviceName;
    }
    return self;
}
@end

const NSTimeInterval TGCallReceiveTimeout = 20;
const NSTimeInterval TGCallRingTimeout = 90;
const NSTimeInterval TGCallConnectTimeout = 30;
const NSTimeInterval TGCallPacketTimeout = 10;

@implementation VoIPControllerHolder

- (instancetype)initWithController:( tgvoip::VoIPController *)controller {
    self = [super init];
    if (self != nil) {
        _controller = controller;
    }
    return self;
}

- ( tgvoip::VoIPController *)controller {
    return _controller;
}

-(void)dealloc {
    _controller->Stop();
    delete _controller;
    
    int bp = 0;
    bp++;
}


@end

@interface CallBridge ()
@property (nonatomic, strong) VoIPControllerHolder *controller;
@property (nonatomic, assign) BOOL _isMuted;
- (void)controllerStateChanged:(int)state;
@end

static void controllerStateCallback(tgvoip::VoIPController *controller, int state)
{
    CallBridge *session = (__bridge CallBridge *)controller->implData;
    [session controllerStateChanged:state];
}



@implementation CallBridge

-(id)initWithProxy:(CProxy *)proxy {
    self = [super init];
    if (self != nil) {
        CVoIPController *controller = new CVoIPController();
        controller->implData = (__bridge void *)self;
        tgvoip::VoIPController::Callbacks callbacks={0};
        callbacks.connectionStateChanged=&controllerStateCallback;
        controller->SetCallbacks(callbacks);
        if (proxy != nil) {
            controller->SetProxy(tgvoip::PROXY_SOCKS5, std::string([proxy.host UTF8String]), proxy.port, std::string([proxy.user UTF8String]), std::string([proxy.pass UTF8String]));
        }
        
        CVoIPController::crypto.sha1 = &TGCallSha1;
        CVoIPController::crypto.sha256 = &TGCallSha256;
        CVoIPController::crypto.rand_bytes = &TGCallRandomBytes;
        CVoIPController::crypto.aes_ige_encrypt = &TGCallAesIgeEncryptInplace;
        CVoIPController::crypto.aes_ige_decrypt = &TGCallAesIgeDecryptInplace;
        CVoIPController::crypto.aes_ctr_encrypt = &TGCallAesCtrEncrypt;
        _controller = [[VoIPControllerHolder alloc] initWithController:controller];
        
    }
    return self;
}

-(void)mute {
    self._isMuted = true;
    _controller.controller->SetMicMute(true);
}

-(void)unmute {
    self._isMuted = false;
    _controller.controller->SetMicMute(false);
}

-(BOOL)isMuted {
    return self._isMuted;
}

- (void)controllerStateChanged:(int)state
{
    if (_stateChangeHandler != nil) {
        _stateChangeHandler(state);
    }
}

+(int32_t)voipMaxLayer {
    return tgvoip::VoIPController::GetConnectionMaxLayer();
}
+(NSString *)voipVersion {
    return [NSString stringWithUTF8String:tgvoip::VoIPController::GetVersion()];
}

+(NSArray<AudioDevice *> *)inputDevices {
    
    std::vector<tgvoip::AudioInputDevice> vector = tgvoip::VoIPController::EnumerateAudioInputs();
    
    NSMutableArray <AudioDevice *> * devices = [[NSMutableArray alloc] init];
    [devices addObject:[[AudioDevice alloc] initWithDeviceId:nil deviceName:@"Default"]];
    for(std::vector<tgvoip::AudioInputDevice>::iterator it = vector.begin(); it != vector.end(); ++it) {
        std::string deviceId = it->id;
        std::string deviceName = it->displayName;
        AudioDevice *device = [[AudioDevice alloc] initWithDeviceId:[NSString stringWithCString:deviceId.c_str() encoding:NSUTF8StringEncoding] deviceName:[NSString stringWithCString:deviceName.c_str() encoding:NSUTF8StringEncoding]];
        [devices addObject:device];
    }
    return devices;
}

+(NSArray<AudioDevice *> *)outputDevices {
    
    std::vector<tgvoip::AudioOutputDevice> vector = tgvoip::VoIPController::EnumerateAudioOutputs();
    
    NSMutableArray <AudioDevice *> * devices = [[NSMutableArray alloc] init];
    [devices addObject:[[AudioDevice alloc] initWithDeviceId:nil deviceName:@"Default"]];
    for(std::vector<tgvoip::AudioOutputDevice>::iterator it = vector.begin(); it != vector.end(); ++it) {
        std::string deviceId = it->id;
        std::string deviceName = it->displayName;
        AudioDevice *device = [[AudioDevice alloc] initWithDeviceId:[NSString stringWithCString:deviceId.c_str() encoding:NSUTF8StringEncoding] deviceName:[NSString stringWithCString:deviceName.c_str() encoding:NSUTF8StringEncoding]];
        [devices addObject:device];
    }
    return devices;
}

-(NSString *)currentInputDeviceId {
    return [NSString stringWithCString:_controller.controller->GetCurrentAudioInputID().c_str() encoding:NSUTF8StringEncoding];
}

-(NSString *)currentOutputDeviceId {
    return [NSString stringWithCString:_controller.controller->GetCurrentAudioOutputID().c_str() encoding:NSUTF8StringEncoding];
}

-(void)setCurrentInputDeviceId:(NSString *)deviceId {
    _controller.controller->SetCurrentAudioInput(std::string([deviceId UTF8String]));
}
-(void)setCurrentOutputDeviceId:(NSString *)deviceId {
    _controller.controller->SetCurrentAudioOutput(std::string([deviceId UTF8String]));
}

-(void)setMutedOtherSounds:(BOOL)mute {
    _controller.controller->SetAudioOutputDuckingEnabled(mute);
}

//
-(void)startTransmissionIfNeeded:(bool)outgoing allowP2p:(bool)allowP2p serializedData:(NSString *)serializedData connection:(TGCallConnection *)connection {
    
    tgvoip::VoIPController::Config config = tgvoip::VoIPController::Config();
    config.initTimeout = TGCallConnectTimeout;
    config.recvTimeout = TGCallPacketTimeout;
    config.dataSaving = tgvoip::DATA_SAVING_NEVER;
    config.enableAEC = false;
    config.enableNS = true;
    config.enableAGC = true;
    
    config.logFilePath = [[@"~/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/voip.log" stringByExpandingTildeInPath] UTF8String];
    
  //  strncpy(config.logFilePath, [[@"~/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/voip.log" stringByExpandingTildeInPath] UTF8String], sizeof(config.logFilePath));    //memset(config.logFilePath, 0, sizeof(config.logFilePath));
    
    _controller.controller->SetConfig(config);
    tgvoip::ServerConfig::GetSharedInstance()->Update(serializedData.UTF8String);
    
    std::vector<tgvoip::Endpoint> endpoints {};
    std::vector<tgvoip::Endpoint>::iterator it = endpoints.begin();
    
    NSArray *connections = [@[connection.defaultConnection] arrayByAddingObjectsFromArray:connection.alternativeConnections];
    for (NSUInteger i = 0; i < connections.count; i++)
    {
        TGCallConnectionDescription *desc = connections[i];
        
        tgvoip::Endpoint endpoint {};
        
        endpoint.id = desc.identifier;
        endpoint.port = (uint32_t)desc.port;
        
        tgvoip::IPv4Address address(std::string(desc.ipv4.UTF8String));
        tgvoip::IPv6Address addressv6(std::string(desc.ipv6.UTF8String));

        
//        endpoint.address = tgvoip::NetworkAddress::IPv4(desc.ipv4.UTF8String);
//        endpoint.v6address = tgvoip::NetworkAddress::IPv4(desc.ipv6.UTF8String);
        endpoint.type = tgvoip::Endpoint::Type::UDP_RELAY;
        endpoint.address = address;
        endpoint.v6address = addressv6;
        [desc.peerTag getBytes:&endpoint.peerTag length:16];
        
        it = endpoints.insert ( it , endpoint );
    }
    
    _controller.controller->SetEncryptionKey((char *)connection.key.bytes, outgoing);
    _controller.controller->SetRemoteEndpoints(endpoints, allowP2p, connection.maxLayer);
    
    
    _controller.controller->Start();
    
    _controller.controller->Connect();
}

-(void)dealloc {
    
    int bp = 0;
    bp += 1;
}


@end

