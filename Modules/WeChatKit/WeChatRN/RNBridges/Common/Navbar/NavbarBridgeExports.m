#import <React/RCTEventEmitter.h>

@interface RCT_EXTERN_MODULE(NavbarBridge, RCTEventEmitter)

RCT_EXTERN_METHOD(setOptions:(NSDictionary *)params)
RCT_EXTERN_METHOD(goBack:(NSDictionary *)params)

@end
