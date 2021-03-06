//
//  PGRequestManager.m
//  PGFrame
//
//  Created by ouyanghua on 16/9/22.
//  Copyright © 2016年 pangu. All rights reserved.
//

#import "PGRequestManager.h"
#import "PGHttpClient.h"
#import "NSString+json.h"
#import "NSString+encrypt.h"
#import "PGCacheManager.h"

@interface PGRequestManager ()<PGHttpClientDelegate>
/*
 所有的请求
 */
@property(atomic, strong)NSMutableDictionary *allClient;
/*
 api请求参数对应的时间戳
 */
@property(atomic, strong)NSMutableDictionary *allApiKeyTime;
@end

static PGRequestManager *s_requestManager = nil;

@implementation PGRequestManager

- (void)dealloc
{
    [self cancelAllClient];
}

+ (PGRequestManager *)shareInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_requestManager = [[PGRequestManager alloc] init];
        s_requestManager.allClient = [[NSMutableDictionary alloc] init];
        s_requestManager.allApiKeyTime = [[NSMutableDictionary alloc] init];
    });
    
    return s_requestManager;
}

- (void)addClient:(PGHttpClient *)client target:(id)target tag:(NSString *)tag
{
    if(client == nil)
    {
        return;
    }
    
    NSString *szClassName = NSStringFromClass([target class]);
    NSString *szTag = szClassName;
    if(tag != nil && tag.length > 0)
    {
        szTag = [NSString stringWithFormat:@"%@_%@",szClassName, tag];
    }
    
    [self cancelClient:szTag];
    [self.allClient setObject:client forKey:szTag];
}

+ (void)cancelClientWithTarget:(id)target type:(PGApiType)type
{
    NSString *szClassName = NSStringFromClass([target class]);
    NSString *szTag = [NSString stringWithFormat:@"%@_%@",szClassName, @(type).stringValue];
    
    [[PGRequestManager shareInstance] cancelClient:szTag];
}

- (void)cancelClient:(NSString *)szTag
{
    if(szTag == nil || szTag.length < 1)
    {
        return;
    }
    
    PGHttpClient *oldClient = [self.allClient objectForKey:szTag];
    if(oldClient != nil)
    {
        [oldClient cancelRequest];
        [self.allClient removeObjectForKey:szTag];
    }
}

- (void)cancelAllClient
{
    NSArray *tagArray = self.allClient.allValues;
    for(NSString *string in tagArray)
    {
        [self cancelClient:string];
    }
}

//普通接口请求
+ (void)startPostClient:(PGApiType)type param:(NSDictionary *)param target:(id<PGApiDelegate>)target extendParam:(NSObject *)extendParam
{
    [[PGRequestManager shareInstance] startClient:@"POST" type:type param:param target:target extendParam:extendParam];
}

+ (void)startGetClient:(PGApiType)type param:(NSDictionary *)param target:(id<PGApiDelegate>)target extendParam:(NSObject *)extendParam
{
    [[PGRequestManager shareInstance] startClient:@"GET" type:type param:param target:target extendParam:extendParam];
}

- (void)startClient:(NSString *)method type:(PGApiType)type param:(NSDictionary *)param target:(id<PGApiDelegate>)target extendParam:(NSObject *)extendParam
{
    PGHttpClient *client = [[PGHttpClient alloc] initWithType:type requestParam:param];
    client.requestMethod = method;
    client.apiDelegate = target;
    client.delegate = self;
    client.extendParam = extendParam;
    
    //需要缓存的接口才做缓存处理
    if([self bEnableStrategy:type])
    {
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        [dic setObject:@(type).stringValue forKey:@"apiType"];
        [dic addEntriesFromDictionary:param];
        NSString *key = [NSString MD5Encrypt:[NSString jsonStringWithDictionary:dic]];
        NSString *dataString = [self cacheSringWithKey:key];
        if(dataString)
        {
            [client parseData:dataString];
            return;
        }
    }
    
    if(target != nil)
        [self addClient:client target:target tag:@(type).stringValue];
    else
        [self addClient:client target:self tag:@(type).stringValue];
    
    [client startRequest];
}

+ (void)startFile:(NSData *)data PostClient:(PGApiType)type param:(NSDictionary *)param target:(id<PGApiDelegate>)target extendParam:(NSObject *)extendParam
{
    PGRequestManager *manger = [PGRequestManager shareInstance];
    PGHttpClient *client = [[PGHttpClient alloc] initWithType:type requestParam:param];
    client.requestMethod = @"POST";
    client.apiDelegate = target;
    client.delegate = manger;
    client.extendParam = extendParam;
    client.fileData = data;
    
    if(target != nil)
        [manger addClient:client target:target tag:@(type).stringValue];
    else
        [manger addClient:client target:manger tag:@(type).stringValue];
    
    [client startPostImageFileData];
}

+ (void)startDownload:(PGApiType)type url:(NSString *)fileUrl local:(NSString *)localPath target:(id<PGApiDelegate>)target extendParam:(NSObject *)extendParam
{
    PGRequestManager *manger = [PGRequestManager shareInstance];
    PGHttpClient *client = [[PGHttpClient alloc] initWithType:type requestParam:nil];
    client.apiDelegate = target;
    client.delegate = manger;
    client.extendParam = extendParam;
    
    if(target != nil)
        [manger addClient:client target:target tag:@(type).stringValue];
    else
        [manger addClient:client target:manger tag:@(type).stringValue];
    
    [client startDownload:fileUrl local:localPath];
}

#pragma mark - PGHttpClientDelegate
- (void)dataRequestSuccess:(PGResultObject *)resultObj client:(PGHttpClient *)client
{
    if(client.apiDelegate)
    {
        [client.apiDelegate dataRequestFinish:resultObj apiType:client.apiType];
    }
}

- (void)dataRequestFailed:(PGResultObject *)resultObj client:(PGHttpClient *)client
{
    if(client.apiDelegate)
    {
        [client.apiDelegate dataRequestFinish:resultObj apiType:client.apiType];
    }
}

- (void)downloadProgress:(NSProgress *)downloadProgress client:(PGHttpClient *)client
{
    if(client.apiDelegate && [client.apiDelegate respondsToSelector:@selector(downloadProgress:apiType:extendParam:)])
    {
        [client.apiDelegate downloadProgress:downloadProgress apiType:client.apiType extendParam:client.extendParam];
    }
}

- (void)dataRequestFinish:(NSString *)resultString client:(PGHttpClient *)client
{
    PGRequestManager *manger = [PGRequestManager shareInstance];
    //需要缓存的接口才做缓存处理
    if([manger bEnableStrategy:client.apiType])
    {
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        [dic setObject:@(client.apiType).stringValue forKey:@"apiType"];
        [dic addEntriesFromDictionary:client.originRequestData];
        NSString *key = [NSString MD5Encrypt:[NSString jsonStringWithDictionary:dic]];
        [PGCacheManager cacheApiData:resultString key:key];
        [self.allApiKeyTime setObject:[NSNumber numberWithDouble:[NSDate date].timeIntervalSince1970] forKey:key];
    }
}

#pragma mark - API请求策略逻辑
- (BOOL)bEnableStrategy:(PGApiType)type
{
    BOOL bEnable = YES;
    switch(type)
    {
        case API_TYPE_LOGIN:
        {
            bEnable = NO;
            break;
        }
        default:
            break;
    }
    return bEnable;
}

- (NSString *)cacheSringWithKey:(NSString *)key
{
    NSString *dataString = nil;
    
    NSNumber *timeNumber = [self.allApiKeyTime objectForKey:key];
    if(timeNumber)
    {
        double nTime = [NSDate date].timeIntervalSince1970 - [timeNumber doubleValue];
        //时间间隔大于120秒
        if(nTime < 120)
        {
            dataString = (NSString *)[PGCacheManager getApiCacheStringWithKey:key];
        }
    }
    
    return dataString;
}

@end
