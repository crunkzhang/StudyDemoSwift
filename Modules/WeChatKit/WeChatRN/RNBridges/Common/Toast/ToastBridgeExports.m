#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(ToastBridge, RCTEventEmitter)

RCT_EXTERN_METHOD(show:(NSDictionary *)params)

@end
