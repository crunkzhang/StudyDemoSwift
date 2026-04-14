#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(CacheBridge, NSObject)

RCT_EXTERN__BLOCKING_SYNCHRONOUS_METHOD(getString:(NSString *)key)
RCT_EXTERN__BLOCKING_SYNCHRONOUS_METHOD(getBool:(NSString *)key)
RCT_EXTERN__BLOCKING_SYNCHRONOUS_METHOD(getNumber:(NSString *)key)

RCT_EXTERN_METHOD(setString:(NSString *)key value:(NSString *)value)
RCT_EXTERN_METHOD(setBool:(NSString *)key value:(BOOL)value)
RCT_EXTERN_METHOD(setNumber:(NSString *)key value:(double)value)
RCT_EXTERN_METHOD(remove:(NSString *)key)

@end
