#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NS_ASSUME_NONNULL_BEGIN

/// S4b-2a 探针：返回 librime 的版本串与链接状态（证明静态库已链入扩展）。
NSString *RimeProbeVersion(void);

/// S4b-2b：把捆绑的 rime 数据复制到可写 shared 目录，首次启动部署 pinyin_simp，
/// 建会话、模拟输入 "nihao" 取候选，返回状态串（含候选与 session）。
NSString *RimeProbeType(NSString *sharedDir, NSString *userDir);

NS_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif
