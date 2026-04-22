#import <React/RCTBridgeModule.h>
#import <ReactCommon/RCTTurboModule.h>
#import <ReactCodegen/WeChatRNSpec/WeChatRNSpec.h>

#define WECHAT_RN_TURBO_MODULE(name) \
  @interface name : NSObject @end \
  @interface name (Spec) <Native##name##Spec> @end \
  _Pragma("clang diagnostic push") \
  _Pragma("clang diagnostic ignored \"-Wprotocol\"") \
  @implementation name (Spec) \
  RCT_EXPORT_MODULE(name) \
  - (std::shared_ptr<facebook::react::TurboModule>)getTurboModule: \
      (const facebook::react::ObjCTurboModule::InitParams &)params { \
    return std::make_shared<facebook::react::Native##name##SpecJSI>(params); \
  } \
  @end \
  _Pragma("clang diagnostic pop")
