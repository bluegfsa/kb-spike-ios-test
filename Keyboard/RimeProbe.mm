#import "RimeProbe.h"
#include <rime_api.h>
#include <string.h>
#import <CommonCrypto/CommonDigest.h>

NSString *RimeProbeVersion(void) {
    RimeApi *api = rime_get_api();
    if (!api) { return @"librime: rime_get_api() == NULL（未链接成功）"; }
    const char *ver = api->get_version ? api->get_version() : "?";
    return [NSString stringWithFormat:@"librime 已链接 · version=%s", ver ? ver : "?"];
}

/// 计算文件的 SHA-256（十六进制小写）。用于「按内容」判断词库是否需要重拷/重部署。
static NSString *KBSHA256File(NSString *path) {
    NSData *d = [NSData dataWithContentsOfFile:path];
    if (!d) { return @""; }
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(d.bytes, (CC_LONG)d.length, hash);
    NSMutableString *s = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) { [s appendFormat:@"%02x", hash[i]]; }
    return s;
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

/// 仅当目标缺失或「内容不同（SHA 不一致）」时才复制。
/// 注意：不能只比文件大小——新旧词库同大小但内容不同会漏拷，导致换了库却还是旧数据。
static BOOL KBCopyIfNeeded(NSString *name, NSString *ext, NSString *dstDir) {
    NSString *p = [[NSBundle mainBundle] pathForResource:name ofType:ext];
    if (!p) { return NO; }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dst = [dstDir stringByAppendingPathComponent:[p lastPathComponent]];
    if ([fm fileExistsAtPath:dst]) {
        NSString *srcSha = KBSHA256File(p);
        NSString *dstSha = KBSHA256File(dst);
        if (srcSha.length > 0 && [srcSha isEqualToString:dstSha]) {
            return YES; // 内容完全一致，跳过拷贝
        }
    }
    [fm removeItemAtPath:dst error:nil];
    return [fm copyItemAtPath:p toPath:dst error:nil];
}

/// 清掉旧的部署编译产物（build/staging 目录下的 *.prism.bin/*.table.bin 等）。
/// 改部署版本时必须清，否则 marker 变了但旧 bin 仍在，增量维护可能不重建。
static void KBClearRimeBuild(NSString *dir) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *subdirs = @[@"build", @"staging"];
    for (NSString *sd in subdirs) {
        NSString *d = [dir stringByAppendingPathComponent:sd];
        [fm removeItemAtPath:d error:nil];
    }
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
    // 配置/词库：仅在缺失或内容不同（SHA 不一致）时复制（一次拷贝，之后跳过）。
    NSArray<NSString *> *yml = @[@"default", @"pinyin_simp.schema", @"pinyin_simp.dict",
                                 @"key_bindings", @"punctuation", @"symbols"];
    for (NSString *n in yml) { KBCopyIfNeeded(n, @"yaml", sharedDir); }

    // 部署版本号与「拼音词典内容的 SHA」绑定：词库一改，版本即变，强制重部署。
    // 不再写死 "v1"——避免同一 userDir 跨装包时 marker 一直是 v1、换库也不重编译。
    NSString *dictPath = [sharedDir stringByAppendingPathComponent:@"pinyin_simp.dict.yaml"];
    NSString *dictSha = KBSHA256File(dictPath);
    NSString *dictSha8 = dictSha.length >= 8 ? [dictSha substringToIndex:8] : dictSha;
    NSString *deployVer = [NSString stringWithFormat:@"v2-%@", dictSha8];

    RimeTraits traits; memset(&traits, 0, sizeof(traits));
    traits.data_size = (int)sizeof(RimeTraits);
    traits.shared_data_dir = [sharedDir UTF8String];
    traits.user_data_dir = [userDir UTF8String];
    traits.log_dir = ""; traits.app_name = "KBSpike"; traits.min_log_level = 0;
    api->setup(&traits);
    api->initialize(&traits);

    // 一次性部署：仅当「版本标记」缺失/不符（含词库内容变了）时才重编译词典。
    NSString *marker = [userDir stringByAppendingPathComponent:@".kb_rime_deploy.ok"];
    NSString *doneVer = [NSString stringWithContentsOfFile:marker encoding:NSUTF8StringEncoding error:nil];
    BOOL needDeploy = ![doneVer isEqualToString:deployVer];
    if (needDeploy) {
        KBClearRimeBuild(sharedDir);
        KBClearRimeBuild(userDir);
        api->start_maintenance(1);
        api->join_maintenance_thread();
        [deployVer writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }

    RimeSessionId sid = api->create_session();
    if (!sid && !needDeploy) {
        // 标记在但加载失败（如 build 目录丢失）→ 清旧 build 后兜底重部署一次。
        KBClearRimeBuild(sharedDir);
        KBClearRimeBuild(userDir);
        api->start_maintenance(1);
        api->join_maintenance_thread();
        [deployVer writeToFile:marker atomically:YES encoding:NSUTF8StringEncoding error:nil];
        sid = api->create_session();
    }
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
