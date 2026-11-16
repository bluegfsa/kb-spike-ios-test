#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

NS_ASSUME_NONNULL_BEGIN

/// 旧探针（B2 起不用，保留仅以防回退）
NSString *RimeProbeVersion(void);
NSString *RimeProbeType(NSString *sharedDir, NSString *userDir);

/// B2 真引擎 API（Swift 通过桥接头调用）
/// 初始化：复制 rime 数据、setup/initialize、部署词典、建会话、选方案。返回是否成功。
BOOL RimeKbInit(NSString *sharedDir, NSString *userDir);
/// 清空当前 composition（切语言/上屏后调用）
void RimeKbReset(void);
/// 送入一个键（keyCode，字母用 ASCII、退格用 0xff08），返回候选文本数组（≤8）。
NSArray<NSString *> *RimeKbInput(int keyCode);
/// 选择第 index 个候选，返回上屏文本（无则 nil）。
NSString * _Nullable RimeKbSelect(int index);

NS_ASSUME_NONNULL_END

#ifdef __cplusplus
}
#endif
