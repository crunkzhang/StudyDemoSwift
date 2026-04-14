#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(PermissionBridge, NSObject)

RCT_EXTERN_METHOD(requestCameraPermission:(RCTPromiseResolveBlock)resolve
                                  rejecter:(RCTPromiseRejectBlock)reject)
RCT_EXTERN_METHOD(requestAlbumPermission:(RCTPromiseResolveBlock)resolve
                                 rejecter:(RCTPromiseRejectBlock)reject)

@end
