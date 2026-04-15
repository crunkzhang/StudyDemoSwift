#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(NetBridge, NSObject)

RCT_EXTERN_METHOD(request:(NSDictionary *)params
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(cancel:(NSString *)requestId)

@end
