//
//  LBDB.h
//  LevelBits
//
//  Created by Kevin O'Neill on 8/02/12.
//  Copyright (c) 2012 Kevin O'Neill. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *LBLevelErrorDomain;

@interface LBDB : NSObject

- (id)initWithPath:(NSString *)path;

- (void)destroy;

- (id <NSCoding>)objectForKey:(NSString *)key error:(NSError **)error;
- (BOOL)setObject:(id <NSCoding>)value forKey:(NSString *)key error:(NSError **)error;
- (BOOL)removeObjectForKey:(NSString *)key error:(NSError **)error;
- (void)enumerateKeysAndValuesUsingBlock:(void (^)(id key, id<NSCoding> value, BOOL *stop))block;

@end
