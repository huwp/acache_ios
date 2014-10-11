/*
 //  CWCacheCenter.m
 //  
 //
 //  Created by huwp on 13-8-20.
 
    <Application_Home>/AppName.app：存放应用程序自身
    <Application_Home>/Documents/：存放用户文档和应用数据文件
    <Application_Home>/Library/：应用程序规范的顶级目录，下面有一些规范定义的的子目录，当然也可以自定义子目录，用于存放应用的文件，但是不宜存放用户数据文件，和document一样会被itunes同步，但不包括caches子目录
    <Application_Home>/Library/Preferences，这里存放程序规范要求的首选项文件
    <Application_Home>/Library/Caches，保存应用的持久化数据，用于应用升级或者应用关闭后的数据保存，不会被itunes同步，所以为了减少同步的时间，可以考虑将一些比较大的文件而又不需要备份的文件放到这个目录下
    <Application_Home>/tmp/，保存应用数据，但不需要持久化的，在应用关闭后，该目录下的数据将删除，也可能系统在程序不运行的时候做清除

    我们的缓存文件，重要的就放到 /Library/Caches 目录， 不太重要的就放到 tmp 目录下。
    暂时没有需要放置到 Documents 目录下的。
 
 
    本期修正
    添加了缓存逻辑， 出于性能考虑，可以现缓存到内存，后面自动缓存到 硬盘的逻辑。
    可以指定是 缓存到 临时文件夹， 如果选不，则缓存到 LibraryCache目录。程序升级的时候，这些数据还会保留。
    现在只有到存储文件的时候，才会去识别数据类型。 这样增加了 缓存到内存的效率。
    以上， 2013.9.12 更新
 
 //
 */

#import "ACache.h"

#define DATE_COMPONENTS (NSYearCalendarUnit| NSMonthCalendarUnit | NSDayCalendarUnit | NSWeekCalendarUnit |  NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit | NSWeekdayCalendarUnit | NSWeekdayOrdinalCalendarUnit)
#define CURRENT_CALENDAR [NSCalendar currentCalendar]

#define DATE_FORMATSTYLE_STANDARD  @"yyyy-MM-dd HH:mm:ss"

@interface NSDate (FormatString)

- (NSString*)string;
- (NSString*)stringWithFormat:(NSString*)fmt;
+ (NSDate*)dateFromString:(NSString*)str withFormat:(NSString*)fmt ;
- (NSDateComponents *)components;
@end

@interface ACache()
{
    NSFileManager *_fileManager;
    NSString *_pathPlist;
    NSMutableArray *_arrsPlist;
}

@end

@implementation ACache

/*
 单实例
 */
+ (ACache*) instance;
{
	static dispatch_once_t once;
    static ACache *mInstance = nil;
    dispatch_once( &once, ^{ mInstance = [[ACache alloc] init]; } );
    return mInstance;
}

// 初始化
- (id)init;
{
	self = [super init];
    if (self) {
        // Custom initialization.
        _fileManager = [[NSFileManager alloc] init];
        
        _pathPlist = [self cachePath:@"cacheinfo.plist"];
        
        _arrsPlist = [NSMutableArray arrayWithContentsOfFile:_pathPlist];
        if (_arrsPlist==nil) {
            _arrsPlist = [NSMutableArray array];
        }
        
        NSLog(@"path=%@\n",_pathPlist);
    }
    return self;
}

#pragma mark - 清除缓存

// 删除指定key 的缓存
- (void) deleteCacheWithKey:(NSString*)key;
{
    NSDictionary *element = [self getElementWithKey:key];
    if (element==nil) {
        return;
    }
    [_arrsPlist removeObject:element];
    [_arrsPlist writeToFile:_pathPlist atomically:YES];
}

//删除所有的缓存数据
- (void) deleteAllCacheAndInfo;
{
    [_arrsPlist removeAllObjects];
    [_arrsPlist writeToFile:_pathPlist atomically:YES];
}


#pragma mark - 获取缓存

- (NSData*)getAsNSData:(NSString*)key;
{
    return [self getAsNSData:key validate:YES];
}

- (NSData *)getAsNSData:(NSString *)key validate:(BOOL)validate;
{
    NSMutableDictionary *element = [self getElementWithKey:key];
    if (element==nil) {
        return nil;
    }
    if (validate) {
        BOOL isValid = [self validateCacheWithElement:element];
        //如果需要验证，并且验证过期，返回nil
        if (isValid==NO) {
            return nil;
        }
    }
    
    NSString *filename = element[@"file"];
    NSString *filePath = [self cachePath:filename];
    if(![_fileManager fileExistsAtPath:filePath])
    {
        NSError *error;
        NSData * data = [NSData dataWithContentsOfFile:filePath options:0 error:&error];
        //如果 element 存在，但是文件判断不存在，则可能是 文件已经出了异常。
        //这个时候 重置文件地址。
        NSLog(@"key=%@ file 不存在，置空 \n error=%@ data.len=[%lu]",key, error, (unsigned long)data.length);
        [element setObject:@"" forKey:@"file"];
        return nil;
    }
    NSData * data = [NSData dataWithContentsOfFile:filePath];
    
    BOOL iszip = NO;
    iszip = [element[@"zip"] boolValue];
    
    if (iszip) {
        id object = [ACache decodeObject:data];
        return object;
    }else {
        return data;
    }
    
    return nil;
}

- (NSString*)getAsNSString:(NSString*)key;
{
    NSData * data = [self getAsNSData:key];
    if (data==nil) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (id)get:(NSString*)key;
{
    return [self get:key validate:YES];
}

- (id)get:(NSString*)key validate:(BOOL)validate;
{
    NSData * data = [self getAsNSData:key validate:validate];
    if (data==nil) {
        return nil;
    }
    NSMutableDictionary *element = [self getElementWithKey:key];
    BOOL isstring = [element[@"string"] boolValue];
    if (isstring) {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return data;
}

- (NSDictionary*)getCacheInfo:(NSString*)key;
{
    NSMutableDictionary *element = [NSMutableDictionary dictionaryWithDictionary:[[self getElementWithKey:key] copy]];
    [element setObject:[self cachePath:element[@"file"]] forKey:@"file"];
    return element;
}

#pragma mark - 缓存

- (void)put:(NSString*)key string:(NSString*)data;
{
    [self put:key data:[data dataUsingEncoding:NSUTF8StringEncoding] timeout:NSNotFound];
}
- (void)put:(NSString*)key data:(NSData*)data;
{
    [self put:key data:data timeout:NSNotFound];
}
- (void)put:(NSString*)key data:(NSData*)data timeout:(NSTimeInterval)time;
{
    if (!data || !key) {
        return;
    }
    NSMutableDictionary *element = [self getOrAddLibraryCacheElementWithKey:key];
    [element setObject:@(time) forKey:@"timeout"];
    
    //写入文件
    [self saveData:data element:element];
}


- (void)saveData:(id)object element:(NSMutableDictionary*)element;
{
    [element setObject:@([[NSDate date] timeIntervalSince1970]) forKey:@"time"];
    
    NSString *filename = element[@"file"];
    BOOL iszip = YES;
    BOOL isstring = NO;
    NSData * data;
    if (object && [object isKindOfClass:[NSData class]]) {
        iszip = NO;
        data = object;
    }else if([object isKindOfClass:[NSString class]]){
        iszip = NO;
        isstring = YES;
        data = [((NSString*)object) dataUsingEncoding:NSUTF8StringEncoding];
    }else {
        data = [ACache encodeObject:object];
    }
    if (data.length==0) {
        return;
    }
    [element setObject:@(iszip) forKey:@"zip"];
    [element setObject:@(isstring) forKey:@"string"];
    [element setObject:@(data.length) forKey:@"len"];
    {
        NSString *path = [self cachePath:filename];
        BOOL flag = [data writeToFile:path atomically:YES];
        if (!flag) {
            NSLog(@"%@ 文件写入失败",filename);
        }
    }
    [_arrsPlist writeToFile:_pathPlist atomically:YES];
}

#pragma mark - util and init

- (NSMutableDictionary*)getElementWithKey:(NSString*)key;
{
    for (NSInteger i=0; i<_arrsPlist.count; i++) {
        NSMutableDictionary *dic = _arrsPlist[i];
        if ([dic[@"key"] isEqualToString:key]) {
            return dic;
        }
    }
    return nil;
}

- (NSMutableDictionary*)getOrAddLibraryCacheElementWithKey:(NSString*)key;
{
    NSMutableDictionary *element = [self getElementWithKey:key];
    NSString *extension = [key pathExtension];
    NSString *filename = [[NSString stringWithFormat:@"cache_%d",abs(arc4random())] stringByAppendingPathExtension:extension];
    if (element==nil) {
        element = [NSMutableDictionary dictionary];
        [element setObject:key forKey:@"key"];
        [element setObject:filename forKey:@"file"];
        [_arrsPlist addObject:element];
    }
    
    NSString *file = element[@"file"];
    if (file.length==0) {
        [element setObject:filename forKey:@"file"];
    }
    
    return element;
}

#pragma mark - 验证数据是否有效，有效返回 YES，无效返回NO
- (BOOL) validateCacheWithElement:(NSDictionary *)element;
{
    NSInteger savetime = [element[@"time"] integerValue];
    NSInteger timeout = [element[@"timeout"] integerValue];
    if (timeout>0) {
        //需要做超时验证
        if ([[NSDate date] timeIntervalSince1970] > savetime+timeout) {
            return NO;
        }
        return YES;
    }
    return YES;
}

//获取下一个工作日的某时某分
+ (NSDate*)getNextT:(NSInteger)hour minutes:(NSInteger)minutes;
{
    NSTimeInterval tt = [[NSDate date] timeIntervalSince1970];
    tt = tt + 24*60*60;
    NSDate *dt = (NSDate*)[NSDate dateWithTimeIntervalSince1970:tt];
    NSDateComponents *components = dt.components;
    while (components.weekday==7 || components.weekday==1) {
        // 周六 或者 周日，需要再后移一天
        tt = tt + 24*60*60;
        dt = (NSDate*)[NSDate dateWithTimeIntervalSince1970:tt];
        components = dt.components;
    }
    components.hour = hour;
    components.minute = minutes;
    components.second = 0;
    
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDate *date = [gregorian dateFromComponents:components];
    return date;
}

//获取明天的某时某分
+ (NSDate*)getTomorrow:(NSInteger)hour minutes:(NSInteger)minutes;
{
    NSTimeInterval tt = [[NSDate date] timeIntervalSince1970];
    tt = tt + 24*60*60;
    NSDate *dt = (NSDate*)[NSDate dateWithTimeIntervalSince1970:tt];
    return dt;
}

+ (NSData*) encodeObject:(id)object;
{
    if (object==nil) {
        return nil;
    }
    NSMutableData *data = [[NSMutableData alloc] init];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    
    [archiver encodeObject:object];
    [archiver finishEncoding];
    
    return data;
}

+ (id)decodeObject:(NSData*)data;
{
    if (data==nil) {
        return nil;
    }
    NSKeyedUnarchiver *vdUnarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    id object =[vdUnarchiver decodeObject];
    
    return object;
}

//获取缓存目录 (Library/Caches) 下的文件 filename
- (NSString*)cachePath:(NSString*)filename;
{
    //创建文件管理器
    NSFileManager *fileManager = [NSFileManager defaultManager];
    //获取路径
    //参数NSDocumentDirectory要获取那种路径
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];//去处需要的路径
    documentsDirectory = [documentsDirectory stringByAppendingPathComponent:@"cssweb"];
    if (![fileManager fileExistsAtPath:documentsDirectory]) {
        if ([fileManager createDirectoryAtPath:documentsDirectory withIntermediateDirectories:YES attributes:nil error:nil]==NO) {
            NSLog(@"文件夹创建失败");
        }
    }
    NSString *path = [documentsDirectory stringByAppendingPathComponent:filename];
    return path;
}

+ (NSString*)createTmpDictory:(NSString*)dictoryname;
{
    //创建文件管理器
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:dictoryname];
    if (![fileManager fileExistsAtPath:path]) {
        if ([fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil]==NO) {
            NSLog(@"文件夹创建失败");
        }
    }
    return path;
}

#pragma mark - 单实例


@end


@implementation NSDate (FormatString)

- (NSString*)string;
{
    return [self stringWithFormat:DATE_FORMATSTYLE_STANDARD];
}

- (NSString*)stringWithFormat:(NSString*)fmt;
{
    static NSDateFormatter *fmtter;
	
    if (fmtter == nil) {
        fmtter = [[NSDateFormatter alloc] init];
    }
	
    if (fmt == nil || [fmt isEqualToString:@""]) {
        fmt = @"HH:mm:ss";
    }
	
    [fmtter setDateFormat:fmt];
	
    return [fmtter stringFromDate:self];
}

+ (NSDate*)dateFromString:(NSString*)str withFormat:(NSString*)fmt ;
{
    static NSDateFormatter *fmtter;
	
    if (fmtter == nil) {
        fmtter = [[NSDateFormatter alloc] init];
    }
	
    if (fmt == nil || [fmt isEqualToString:@""]) {
        fmt = @"HH:mm:ss";
    }
	
    [fmtter setDateFormat:fmt];
	
    return [fmtter dateFromString:str];
}

- (NSDateComponents *)components;
{
    NSDateComponents *components = [CURRENT_CALENDAR components:DATE_COMPONENTS fromDate:self];
    return components;
}


@end

