//
//  TTLog.h
//  TimeTracker
//
//  Created by Lieven Dekeyser on 14/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import "TTEvent.h"


@interface TTInterval : NSObject
@property (nonatomic, copy) NSDate * startTime;
@property (nonatomic, copy) NSDate * endTime;
@property (nonatomic, readonly) NSTimeInterval duration;
@end // TTInterval


@interface TTLogItem : NSObject

- (void)beginInterval:(NSDate *)inStartTime;
- (void)endInterval:(NSDate *)inEndTime;

@property (nonatomic, readonly, strong) NSArray * intervals;
@property (nonatomic, readonly) NSTimeInterval totalTime;

@end // TTLogItem



@interface TTTaskLog : TTLogItem

@property (nonatomic, readonly, copy) NSString * taskID;
@property (nonatomic, readonly, copy) NSString * taskName;

- (instancetype)initWithEvent:(TTEvent *)inEvent;

@end // TTTaskLog


@interface TTProjectLog : TTLogItem

@property (nonatomic, readonly, copy) NSString * projectID;
@property (nonatomic, readonly, copy) NSString * projectName;

@property (nonatomic, readonly, strong) NSDictionary * taskLogs; // id -> TTTaskLog

- (instancetype)initWithEvent:(TTEvent *)inEvent;

- (BOOL)addEvent:(TTEvent *)inEvent;

@end // TTProjectLog


@interface TTLog : NSObject

@property (nonatomic, readonly, strong) NSDictionary * projectLogs;

- (void)addEvent:(TTEvent *)inEvent;

@end // TTLog