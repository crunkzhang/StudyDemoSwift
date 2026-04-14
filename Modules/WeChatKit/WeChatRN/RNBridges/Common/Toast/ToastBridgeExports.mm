#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(ToastBridge, NSObject)

RCT_EXTERN_METHOD(show:(NSDictionary *)payload)

@end
