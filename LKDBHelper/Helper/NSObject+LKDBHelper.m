//
//  NSObject+LKDBHelper.m
//  LKDBHelper
//
//  Created by LJH on 13-6-8.
//  Copyright (c) 2013年 ljh. All rights reserved.
//

#import "NSObject+LKDBHelper.h"

@implementation NSObject (LKDBHelper_Delegate)

+ (void)dbDidCreateTable:(LKDBHelper*)helper tableName:(NSString*)tableName {}
+ (void)dbDidAlterTable:(LKDBHelper*)helper tableName:(NSString*)tableName addColumns:(NSArray*)columns {}

+ (void)dbDidInserted:(NSObject*)entity result:(BOOL)result {}
+ (void)dbDidDeleted:(NSObject*)entity result:(BOOL)result {}
+ (void)dbDidUpdated:(NSObject*)entity result:(BOOL)result {}
+ (void)dbDidSeleted:(NSObject*)entity {}

+ (BOOL)dbWillDelete:(NSObject*)entity
{
    return YES;
}
+ (BOOL)dbWillInsert:(NSObject*)entity
{
    return YES;
}
+ (BOOL)dbWillUpdate:(NSObject*)entity
{
    return YES;
}
@end

@implementation NSObject (LKDBHelper)

#pragma mark - simplify synchronous function
+ (BOOL)checkModelClass:(NSObject*)model
{
    if ([model isMemberOfClass:self])
        return YES;

    NSLog(@"%@ can not use %@", NSStringFromClass(self), NSStringFromClass(model.class));
    return NO;
}
+ (NSInteger)rowCountWithWhereFormat:(id)where, ...
{
    if ([where isKindOfClass:[NSString class]]) {
        va_list list;
        va_start(list, where);
        where = [[NSString alloc] initWithFormat:where arguments:list];
        va_end(list);
    }
    return [[self getUsingLKDBHelper] rowCount:self where:where];
}
+ (NSInteger)rowCountWithWhere:(id)where, ...
{
    if ([where isKindOfClass:[NSString class]]) {
        va_list list;
        va_start(list, where);
        where = [[NSString alloc] initWithFormat:where arguments:list];
        va_end(list);
    }
    return [[self getUsingLKDBHelper] rowCount:self where:where];
}
+ (NSMutableArray*)searchColumn:(id)columns where:(id)where orderBy:(NSString*)orderBy offset:(NSInteger)offset count:(NSInteger)count
{
    return [[self getUsingLKDBHelper] search:self column:columns where:where orderBy:orderBy offset:offset count:count];
}
+ (NSMutableArray*)searchWithWhere:(id)where orderBy:(NSString*)orderBy offset:(NSInteger)offset count:(NSInteger)count
{
    return [[self getUsingLKDBHelper] search:self where:where orderBy:orderBy offset:offset count:count];
}
+ (NSMutableArray*)searchWithWhere:(id)where
{
    return [[self getUsingLKDBHelper] search:self where:where orderBy:nil offset:0 count:0];
}
+ (NSMutableArray*)searchWithSQL:(NSString*)sql
{
    return [[self getUsingLKDBHelper] searchWithSQL:sql toClass:self];
}
+ (id)searchSingleWithWhere:(id)where orderBy:(NSString*)orderBy
{
    return [[self getUsingLKDBHelper] searchSingle:self where:where orderBy:orderBy];
}

+ (BOOL)insertToDB:(NSObject*)model
{

    if ([self checkModelClass:model]) {
        return [[self getUsingLKDBHelper] insertToDB:model];
    }
    return NO;
}
+ (BOOL)insertWhenNotExists:(NSObject*)model
{
    if ([self checkModelClass:model]) {
        return [[self getUsingLKDBHelper] insertWhenNotExists:model];
    }
    return NO;
}
+ (BOOL)updateToDB:(NSObject*)model where:(id)where, ...
{
    if ([self checkModelClass:model]) {
        if ([where isKindOfClass:[NSString class]]) {
            va_list list;
            va_start(list, where);
            where = [[NSString alloc] initWithFormat:where arguments:list];
            va_end(list);
        }
        return [[self getUsingLKDBHelper] updateToDB:model where:where];
    }
    return NO;
}
+ (BOOL)updateToDBWithSet:(NSString*)sets where:(id)where, ...
{
    if ([where isKindOfClass:[NSString class]]) {
        va_list list;
        va_start(list, where);
        where = [[NSString alloc] initWithFormat:where arguments:list];
        va_end(list);
    }
    return [[self getUsingLKDBHelper] updateToDB:self set:sets where:where];
}
+ (BOOL)deleteToDB:(NSObject*)model
{
    if ([self checkModelClass:model]) {
        return [[self getUsingLKDBHelper] deleteToDB:model];
    }
    return NO;
}
+ (BOOL)deleteWithWhere:(id)where, ...
{
    if ([where isKindOfClass:[NSString class]]) {
        va_list list;
        va_start(list, where);
        where = [[NSString alloc] initWithFormat:where arguments:list];
        va_end(list);
    }
    return [[self getUsingLKDBHelper] deleteWithClass:self where:where];
}
+ (BOOL)isExistsWithModel:(NSObject*)model
{
    if ([self checkModelClass:model]) {
        return [[self getUsingLKDBHelper] isExistsModel:model];
    }
    return NO;
}

- (BOOL)updateToDB
{
    if (self.rowid > 0) {
        return [self.class updateToDB:self where:nil];
    }
    else {
        return [self saveToDB];
    }
}
- (BOOL)saveToDB
{
    return [self.class insertToDB:self];
}
- (BOOL)deleteToDB
{
    return [self.class deleteToDB:self];
}
- (BOOL)isExistsFromDB
{
    return [self.class isExistsWithModel:self];
}

+ (void)insertArrayByAsyncToDB:(NSArray*)models
{
    [self insertArrayByAsyncToDB:models completed:nil];
}
+ (void)insertArrayByAsyncToDB:(NSArray*)models completed:(void (^)(BOOL))completedBlock
{
    if (models.count > 0) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [self insertToDBWithArray:models filter:nil completed:completedBlock];
        });
    }
}

+ (void)insertToDBWithArray:(NSArray*)models filter:(void (^)(id model, BOOL inserted, BOOL* rollback))filter
{
    [self insertToDBWithArray:models filter:filter completed:nil];
}

+ (void)insertToDBWithArray:(NSArray*)models filter:(void (^)(id model, BOOL inserted, BOOL* rollback))filter completed:(void (^)(BOOL))completedBlock
{
    __block BOOL allInserted = YES;
    [[self getUsingLKDBHelper] executeForTransaction:^BOOL(LKDBHelper* helper) {
        BOOL isRollback = NO;
        for (int i = 0; i < models.count; i++) {
            id obj = [models objectAtIndex:i];
            BOOL inserted = [helper insertToDB:obj];
            allInserted &= inserted;
            if (filter) {
                filter(obj, inserted, &isRollback);
            }
            if (isRollback) {
                allInserted = NO;
                break;
            }
        }
        return (isRollback == NO);
    }];
    
    if (completedBlock) {
        completedBlock(allInserted);
    }
    
}
//新加入方法start
+(NSMutableArray *)searchRawSqliteWithOriginalClass:(Class )originalClass withFinishedBlock:(void(^ _Nullable)(id _Nullable data))finishedBlock andErrorBlock:(void(^ _Nullable)(NSError * _Nullable error))errorBlock
{
    NSString *tableName=[self performSelector:@selector(getTableName)];
    NSString *sql = [NSString stringWithFormat:@"select * from %@",tableName];
    
    NSString *originalDataTableName=[originalClass performSelector:@selector(getTableName)];
    NSString *originalDataSql = [NSString stringWithFormat:@"select * from %@",originalDataTableName];
    [self searchRawSqliteDataWithOriginalDataSql:originalDataSql sql:sql withFinishedBlock:^(id  _Nullable data) {
        if (finishedBlock) {
            finishedBlock(data);
        }
    } andErrorBlock:^(NSError * _Nullable error) {
        if (errorBlock) {
            errorBlock(error);
        }
    }];
//    [self searchRawSqliteDataWithSql:sql withFinishedBlock:^(id  _Nullable data) {
//        if (finishedBlock) {
//            finishedBlock(data);
//        }
//    } andErrorBlock:^(NSError * _Nullable error) {
//        if (errorBlock) {
//            errorBlock(error);
//        }
//    }];
//   [self searchRawSqliteDataWithSql:sql withFinishedBlock:finishedBlock andErrorBlock:errorBlock];
    return nil;
}
+(NSMutableArray *)searchRawSqliteDataWithOriginalDataSql:(NSString *)originalDataSql sql:(NSString *)sql withFinishedBlock:(void(^ _Nullable)(id _Nullable data))finishedBlock andErrorBlock:(void(^ _Nullable)(NSError * _Nullable error))errorBlock
{
    LKDBHelper *dbHelper=[self getUsingLKDBHelper];
   __block NSMutableArray *resultArray = [NSMutableArray array];
    if (!sql || [sql length]==0) {
        NSString *tableName=[self performSelector:@selector(getTableName)];
        sql =[NSString stringWithFormat:@"select * from %@",tableName];
    }

    __block NSMutableArray* results = nil;

    [dbHelper executeDB:^(FMDatabase* db) {
        FMResultSet* set = [db executeQuery:sql];
        while ([set next]) {
            NSMutableDictionary *resultDict=[NSMutableDictionary dictionary];
            for (int index=0; index<set.columnCount; index++) {
                resultDict[[set columnNameForIndex:index]]=[set stringForColumnIndex:index];
            }
            [resultArray addObject:resultDict];
            
        }
        NSMutableArray *originalDataArray = [NSMutableArray array];
        NSMutableDictionary *originalDataDict =[NSMutableDictionary dictionary];
        FMResultSet* originalDataSet = [db executeQuery:originalDataSql];
        while ([originalDataSet next]) {

            for (int index=0; index<originalDataSet.columnCount; index++) {
                originalDataDict[[originalDataSet columnNameForIndex:index]]=[originalDataSet stringForColumnIndex:index];
            }
            
        }
        originalDataDict[@"users"] = resultArray;
        NSLog(@"originalDataDict=%@",originalDataDict);
        if (finishedBlock) {
            finishedBlock(originalDataDict);
        }
        [set close];
    }];
    return results;
}
//新加入方法end
@end