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

/// 旧探针（独立初始化 + 打印候选），保留兼容；B2 主用 RimeKb*。
NSString *RimeProbeType(NSString *sharedDir, NSString *userDir) {
    RimeApi *api = rime_get_api();
    if (!api) { return @"librime: rime_get_api() == NULL"; }
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:sharedDir withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:userDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSArray<NSString *> *yml = @[@"default", @"pinyin_simp.schema", @"pinyin_simp.dict",
                                 @"key_bindings", @"punctuation", @"symbols"];
    int copied = 0;
    for (NSString *n in yml) { if (KBCopyResource(n, @"yaml", sharedDir)) { copied++; } }
    RimeTraits traits; memset(&traits, 0, sizeof(traits));
    traits.data_size = (int)sizeof(RimeTraits);
    traits.shared_data_dir = [sharedDir UTF8String];
    traits.user_data_dir = [userDir UTF8String];
    traits.log_dir = ""; traits.app_name = "KBSpike"; traits.min_log_level = 0;
    api->setup(&traits); api->initialize(&traits);
    api->start_maintenance(1); api->join_maintenance_thread();
    RimeSessionId sid = api->create_session();
    if (sid) { api->select_schema(sid, "pinyin_simp"); }
    return [NSString stringWithFormat:@"librime 部署完成(复制%d/6) · session=%llu", copied, (unsigned long long)sid];
}

// ===================== B2 真引擎 =====================
static RimeApi *g_api = NULL;
static RimeSessionId g_sid = 0;

BOOL RimeKbInit(NSString *sharedDir, NSString *userDir) {
    if (g_api && g_sid) { return YES; }
    RimeApi *api = rime_get_api();
    if (!api) { return NO; }
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:sharedDir withIntermediateDirectories:YES attributes:nil error:nil];
    [fm createDirectoryAtPath:userDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSArray<NSString *> *yml = @[@"default", @"pinyin_simp.schema", @"pinyin_simp.dict",
                                 @"key_bindings", @"punctuation", @"symbols"];
    for (NSString *n in yml) { KBCopyResource(n, @"yaml", sharedDir); }
    RimeTraits traits; memset(&traits, 0, sizeof(traits));
    traits.data_size = (int)sizeof(RimeTraits);
    traits.shared_data_dir = [sharedDir UTF8String];
    traits.user_data_dir = [userDir UTF8String];
    traits.log_dir = ""; traits.app_name = "KBSpike"; traits.min_log_level = 0;
    api->setup(&traits);
    api->initialize(&traits);
    api->start_maintenance(1);
    api->join_maintenance_thread();
    RimeSessionId sid = api->create_session();
    if (!sid) { return NO; }
    api->select_schema(sid, "pinyin_simp");
    g_api = api; g_sid = sid;
    return YES;
}

void RimeKbReset(void) {
    if (!g_api || !g_sid) { return; }
    g_api->destroy_session(g_sid);
    g_sid = g_api->create_session();
    if (g_sid) { g_api->select_schema(g_sid, "pinyin_simp"); }
}

NSArray<NSString *> *RimeKbInput(int keyCode) {
    if (!g_api || !g_sid) { return @[]; }
    g_api->process_key(g_sid, keyCode, 0);
    NSMutableArray<NSString *> *a = [NSMutableArray array];
    RIME_STRUCT(RimeContext, ctx);
    if (g_api->get_context(g_sid, &ctx) && ctx.menu.num_candidates > 0) {
        int n = ctx.menu.num_candidates < 8 ? ctx.menu.num_candidates : 8;
        for (int i = 0; i < n; i++) {
            const char *tx = ctx.menu.candidates[i].text;
            if (tx) {
                NSString *s = [NSString stringWithUTF8String:tx];
                if (s && s.length) { [a addObject:s]; }
            }
        }
    }
    g_api->free_context(&ctx);
    return a;
}

NSString * _Nullable RimeKbSelect(int index) {
    if (!g_api || !g_sid) { return nil; }
    if (!g_api->select_candidate(g_sid, (size_t)index)) { return nil; }
    RIME_STRUCT(RimeCommit, commit);
    NSString *out = nil;
    if (g_api->get_commit(g_sid, &commit) && commit.text) {
        out = [NSString stringWithUTF8String:commit.text];
    }
    g_api->free_commit(&commit);
    return out;
}
