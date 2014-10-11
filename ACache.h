/*
//  CWCacheCenter.h
//  
//  Created by huwp on 12-7-22.
//  Copyright (c) 2012年 北京中软万维上海分公司. All rights reserved.
*/

#import <Foundation/Foundation.h>

@interface ACache : NSObject

// 单实例
+ (ACache *) instance;

//创建临时目录
+ (NSString*)createTmpDictory:(NSString*)dictoryname;

//获取下一个工作日的某时某分
+ (NSDate*)getNextT:(NSInteger)hour minutes:(NSInteger)minutes;

//获取明天的某时某分
+ (NSDate*)getTomorrow:(NSInteger)hour minutes:(NSInteger)minutes;

// 获取缓存内容的文件信息
- (NSDictionary*)getCacheInfo:(NSString*)key;

// 缓存接口
- (void)put:(NSString*)key data:(NSData*)data;
- (void)put:(NSString*)key data:(NSData*)data timeout:(NSTimeInterval)time;
- (void)put:(NSString*)key string:(NSString*)data;

- (id)get:(NSString*)key;
- (id)get:(NSString*)key validate:(BOOL)validate;

- (NSData *)getAsNSData:(NSString*)key;
- (NSData *)getAsNSData:(NSString *)key validate:(BOOL)validate;

- (NSString *)getAsNSString:(NSString*)key;


//删除所有的缓存数据
- (void) deleteAllCacheAndInfo;
// 删除指定key 的缓存
- (void) deleteCacheWithKey:(NSString*)key;

@end
