#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NS_ASSUME_NONNULL_BEGIN

/// S4b-2a 探针：返回 librime 的版本串与链接状态（证明 xcframework 静态库已链入扩展）。
NSString *RimeProbeVersion(void);

/// S4b-2a 探针：用给定 shared/user 数据目录初始化 librime 引擎（不加载词库，只起引擎+插件），
/// 返回状态串（含版本、是否创建了会话）。用于测「引擎本体+插件」的 footprint 基线。
NSString *RimeProbeInit(NSString *sharedDir, NSString *userDir);

NS_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif
