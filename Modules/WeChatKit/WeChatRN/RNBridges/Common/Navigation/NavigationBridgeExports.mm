#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(NavigationBridge, NSObject)

RCT_EXTERN_METHOD(push:(NSDictionary *)payload)
RCT_EXTERN_METHOD(pop:(NSDictionary *)payload)
RCT_EXTERN_METHOD(goBack:(NSDictionary *)payload)
RCT_EXTERN_METHOD(present:(NSDictionary *)payload)
RCT_EXTERN_METHOD(dismiss:(NSDictionary *)payload)
RCT_EXTERN_METHOD(replace:(NSDictionary *)payload)
RCT_EXTERN_METHOD(pushURL:(NSString *)url)
RCT_EXTERN_METHOD(replaceURL:(NSString *)url)

@end
