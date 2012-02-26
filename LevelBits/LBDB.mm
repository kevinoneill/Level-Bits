//
//  LBDB.m
//  LevelBits
//
//  Created by Kevin O'Neill on 8/02/12.
//  Copyright (c) 2012 Kevin O'Neill. All rights reserved.
//

#import "LBDB.h"

#import <leveldb/db.h>
#import <leveldb/options.h>

NSString *LBLevelErrorDomain = @"au.id.oneill.levelbits.error";

static const NSInteger lb_error_read = 1;
static const NSInteger lb_error_write = 2;
static const NSInteger lb_error_delete = 3;

static inline NSError *lb_error_for_status(NSInteger error_code, leveldb::Status *status)
{
  NSDictionary *info = [NSDictionary dictionaryWithObject:[NSString stringWithUTF8String:status->ToString().c_str()]
                                                   forKey:NSLocalizedDescriptionKey];

  return [NSError errorWithDomain:LBLevelErrorDomain code:error_code userInfo:info];
}

static inline leveldb::Slice lb_slice_for_object(id <NSCoding> object)
{
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object];
  return leveldb::Slice((const char *)[data bytes], (size_t)[data length]);
}

static inline id <NSCoding> lb_object_for_slice(leveldb::Slice slice)
{
  NSData *data = [NSData dataWithBytes:slice.data() length:slice.size()];  
  return [data length] > 0 ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil; 
}

static inline NSString * lb_string_for_slice(leveldb::Slice slice)
{
  return [[[NSString alloc] initWithBytes:slice.data() length:slice.size() encoding:NSUTF8StringEncoding] autorelease];
}

static inline leveldb::Slice lb_slice_for_string(NSString *string)
{
  return leveldb::Slice((char *)[string UTF8String], [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
}

@interface LBDB ()
{
  NSString *path_;
  leveldb::DB *db_;
}

- (BOOL)store:(leveldb::Slice)value forKey:(leveldb::Slice)key error:(NSError **)error;
- (BOOL)deleteKey:(leveldb::Slice)key error:(NSError **)error;
- (id <NSCoding>)readObjectForKey:(leveldb::Slice)key error:(NSError **)error;

@end

@implementation LBDB

- (id)initWithPath:(NSString *)path;
{
  if ((self = [super init]))
  {
    BOOL is_viable = [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
    
    if (is_viable)
    {
      path_ = [path copy];
      
      leveldb::Options options;
      options.create_if_missing = true;
      
      leveldb::Status status = leveldb::DB::Open(options, [path_ UTF8String], &db_);
      if (!status.ok())
      {
        is_viable = NO;
      }
    }
    
    if (!is_viable)
    {
      [self autorelease];
      return nil;
    }
  }
  
  return self;
}

- (id)init
{
  NSString *library = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  NSString * path = [library stringByAppendingPathComponent:@"lb.db"];
  
  return [self initWithPath:path];
}

- (void)destroy;
{  
  if (db_ != NULL)
  { 
    delete db_;
    db_ = NULL;
  }
  
  leveldb::Options options;
  leveldb::DestroyDB([path_ UTF8String], options);  
}

- (void)dealloc
{
  [path_ release];
  
  if (db_ != NULL)
  { 
    delete db_;
  }
  
  [super dealloc];
}

- (BOOL)setObject:(id <NSCoding>)value forKey:(NSString *)key error:(NSError **)error;
{
  return [self store:lb_slice_for_object(value) forKey:lb_slice_for_string(key) error:error];
}

- (id <NSCoding>)objectForKey:(NSString *)key error:(NSError **)error;
{
  return [self readObjectForKey:lb_slice_for_string(key) error:error];
}

- (BOOL)removeObjectForKey:(NSString *)key error:(NSError **)error;
{
  return [self deleteKey:lb_slice_for_string(key) error:error];
}

#pragma mark - Slice Operations

- (BOOL)store:(leveldb::Slice)value forKey:(leveldb::Slice)key error:(NSError **)error;
{
  leveldb::Status status = db_->Put(leveldb::WriteOptions(), key, value);
  
  if(!status.ok() && nil != error)
  {
    *error = lb_error_for_status(lb_error_write, &status);
  }
  
  return status.ok();
}

- (id <NSCoding>)readObjectForKey:(leveldb::Slice)key error:(NSError **)error;
{
  std::string result;
  
  leveldb::Status status = db_->Get(leveldb::ReadOptions(), key, &result);
  
  if (!(status.ok() || status.IsNotFound()) && nil != error)
  {
    *error = lb_error_for_status(lb_error_read, &status);
  }
  
  return status.IsNotFound() ? nil : lb_object_for_slice(result);
}

- (BOOL)deleteKey:(leveldb::Slice)key error:(NSError **)error;
{
  leveldb::Status status = db_->Delete(leveldb::WriteOptions(), key);
  
  if(!status.ok() && nil != error)
  {
    *error = lb_error_for_status(lb_error_delete, &status);
  }
  
  return status.ok();
}

@end
