#import "RimeProbe.h"
#include <rime_api.h>
#include <string.h>

NSString *RimeProbeVersion(void) {
    RimeApi *api = rime_get_api();
    if (!api) { return @"librime: rime_get_api() == NULL（未链接成功）"; }
    const char *ver = api->get_version ? api->get_version() : "?";
    return [NSString stringWithFormat:@"librime 已链接 · version=%s", ver ? ver : "?"];
}

NSString *RimeProbeInit(NSString *sharedDir, NSString *userDir) {
    RimeApi *api = rime_get_api();
    if (!api) { return @"librime: rime_get_api() == NULL"; }
    const char *ver = api->get_version ? api->get_version() : "?";

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:sharedDir withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:userDir withIntermediateDirectories:YES attributes:nil error:nil];

    RimeTraits traits;
    memset(&traits, 0, sizeof(traits));
    traits.data_size = (int)sizeof(RimeTraits);
    traits.shared_data_dir = [sharedDir UTF8String];
    traits.user_data_dir = [userDir UTF8String];
    traits.log_dir = "";            // 不落日志文件
    traits.app_name = "KBSpike";
    traits.min_log_level = 0;

    api->setup(&traits);
    api->initialize(&traits);

    RimeSessionId sid = api->create_session();
    return [NSString stringWithFormat:@"librime 引擎已初始化 · v%s · session=%llu",
            ver ? ver : "?", (unsigned long long)sid];
}
