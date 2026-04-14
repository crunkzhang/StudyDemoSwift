#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(ScanBridge, NSObject)

RCT_EXTERN_METHOD(openAlbum:(NSDictionary *)payload
                   resolver:(RCTPromiseResolveBlock)resolve
                   rejecter:(RCTPromiseRejectBlock)reject)

@end
