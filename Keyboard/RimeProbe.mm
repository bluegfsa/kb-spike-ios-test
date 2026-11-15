#import "RimeProbe.h"
#include <rime_api.h>
#include <string.h>

NSString *RimeProbeVersion(void) {
    RimeApi *api = rime_get_api();
    if (!api) { return @"librime: rime_get_api() == NULL（未链接成功）"; }
    const char *ver = api->get_version ? api->get_version() : "?";
    return [NSString stringWithFormat:@"librime 已链接 · version=%s", ver ? ver : "?"];
}

/// 从扩展 bundle 取资源文件，复制到可写 shared 目录。
static BOOL KBCopyResource(NSString *name, NSString *ext, NSString *dstDir) {
    NSString *p = [[NSBundle mainBundle] pathForResource:name ofType:ext];
    if (!p) { return NO; }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dst = [dstDir stringByAppendingPathComponent:[p lastPathComponent]];
    [fm removeItemAtPath:dst error:nil];
    return [fm copyItemAtPath:p toPath:dst error:nil];
}

NSString *RimeProbeType(NSString *sharedDir, NSString *userDir) {
    RimeApi *api = rime_get_api();
    if (!api) { return @"librime: rime_get_api() == NULL"; }
    const char *ver = api->get_version ? api->get_version() : "?";

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:sharedDir withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:userDir withIntermediateDirectories:YES attributes:nil error:nil];

    NSArray<NSString *> *yml = @[@"default", @"pinyin_simp.schema", @"pinyin_simp.dict",
                                 @"key_bindings", @"punctuation", @"symbols"];
    int copied = 0;
    for (NSString *n in yml) { if (KBCopyResource(n, @"yaml", sharedDir)) { copied++; } }

    RimeTraits traits;
    memset(&traits, 0, sizeof(traits));
    traits.data_size = (int)sizeof(RimeTraits);
    traits.shared_data_dir = [sharedDir UTF8String];
    traits.user_data_dir = [userDir UTF8String];
    traits.log_dir = "";
    traits.app_name = "KBSpike";
    traits.min_log_level = 0;

    api->setup(&traits);
    api->initialize(&traits);
    api->start_maintenance(1);          // 首次部署：编译 pinyin_simp 词典为 .bin
    api->join_maintenance_thread();

    RimeSessionId sid = api->create_session();
    if (sid) { api->select_schema(sid, "pinyin_simp"); }

    const char *typed = "nihao";
    for (const char *p = typed; *p; ++p) {
        api->process_key(sid, (int)(unsigned char)(*p), 0);
    }

    NSMutableString *cand = [NSMutableString string];
    RIME_STRUCT(RimeContext, ctx);
    if (api->get_context(sid, &ctx) && ctx.menu.num_candidates > 0) {
        int n = ctx.menu.num_candidates < 6 ? ctx.menu.num_candidates : 6;
        for (int i = 0; i < n; i++) {
            const char *tx = ctx.menu.candidates[i].text;
            if (tx) { if (cand.length) { [cand appendString:@" / "]; } [cand appendFormat:@"%s", tx]; }
        }
    }
    api->free_context(&ctx);

    return [NSString stringWithFormat:@"librime 部署完成(复制%d/6) · v%s · session=%llu · nihao→ %@",
            copied, ver ? ver : "?", (unsigned long long)sid,
            cand.length ? cand : @"(无候选，可能部署未完成)"];
}
