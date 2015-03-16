//
//  TTProjectLog.m
//  TimeTracker
//
//  Created by Lieven Dekeyser on 14/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import "TTLog.h"
#import "TTController.h"

@implementation  TTInterval

- (NSTimeInterval)duration
{
	return [self.endTime timeIntervalSinceDate:self.startTime];
}

@end // TTInterval


@implementation TTLogItem
{
	TTInterval * _currentInterval;
	NSMutableArray * _intervals;
}

- (instancetype)init
{
	if ((self = [super init]))
	{
		_intervals = [NSMutableArray new];
	}
	return self;
}

- (void)beginInterval:(NSDate *)inStartTime
{
	_currentInterval = [TTInterval new];
	_currentInterval.startTime = inStartTime;
}

- (void)endInterval:(NSDate *)inEndTime
{
	if (_currentInterval)
	{
		_currentInterval.endTime = inEndTime;
		[_intervals addObject:_currentInterval];
		_currentInterval = nil;
	}
}

- (NSArray *)intervals
{
	return _intervals;
}

- (NSTimeInterval)totalTime
{
	NSTimeInterval result = 0.0;
	for (TTInterval * interval in _intervals)
	{
		result += interval.duration;
	}
	return result;
}

@end // TTLogItem


@implementation TTTaskLog

- (instancetype)initWithEvent:(TTEvent *)inEvent
{
	if ((self = [super init]))
	{
		_taskID = [inEvent.taskID copy];
		_taskName = [inEvent.taskName copy];
		
		[self beginInterval:inEvent.time];
	}
	return self;
}

- (BOOL)addEvent:(TTEvent *)inEvent
{
	[self endInterval:inEvent.time];
	
	if ([inEvent.taskID isEqual:self.taskID])
	{
		[self beginInterval:inEvent.time];
		return YES;
	}
	else
	{
		return NO;
	}
}

@end // TTTaskLog



@implementation TTProjectLog
{
	TTTaskLog * _currentTaskLog;
	NSMutableDictionary * _taskLogs;
}

- (instancetype)initWithEvent:(TTEvent *)inEvent
{
	if ((self = [super init]))
	{
		_projectID = [inEvent.projectID copy];
		_projectName = [inEvent.projectName copy];
		
		_taskLogs = [NSMutableDictionary new];
		
		if (inEvent.taskID)
		{
			_currentTaskLog = [[TTTaskLog alloc] initWithEvent:inEvent];
			_taskLogs[_currentTaskLog.taskID] = _currentTaskLog;
		}
		
		[self beginInterval:inEvent.time];
	}
	return self;
}

- (BOOL)addEvent:(TTEvent *)inEvent
{
	if (! [_currentTaskLog addEvent:inEvent])
	{
		_currentTaskLog = nil;
		
		if (inEvent.taskID)
		{
			_currentTaskLog = _taskLogs[inEvent.taskID];
			
			if (_currentTaskLog == nil)
			{
				_currentTaskLog = [[TTTaskLog alloc] initWithEvent:inEvent];
				_taskLogs[_currentTaskLog.taskID] = _currentTaskLog;
			}
			else
			{
				[_currentTaskLog addEvent:inEvent];
			}
		}
	}
	
	if ([inEvent.projectID isEqual:self.projectID])
	{
		return YES;
	}
	else
	{
		[self endInterval:inEvent.time];
		return NO;
	}
}


@end // TTProjectLog


@implementation TTLog
{
	TTProjectLog * _currentProjectLog;
	NSMutableDictionary * _projectLogs;
}

- (instancetype)init
{
	if ((self = [super init]))
	{
		_projectLogs = [NSMutableDictionary new];
	}
	return self;
}

- (NSDictionary *)projectLogs
{
	return _projectLogs;
}

- (void)addEvent:(TTEvent *)inEvent
{
	if (! [_currentProjectLog addEvent:inEvent])
	{
		_currentProjectLog = nil;
		
		if (inEvent.projectID)
		{
			_currentProjectLog = _projectLogs[inEvent.projectID];
			
			if (_currentProjectLog == nil)
			{
				_currentProjectLog = [[TTProjectLog alloc] initWithEvent:inEvent];
				_projectLogs[_currentProjectLog.projectID] = _currentProjectLog;
			}
			else
			{
				[_currentProjectLog addEvent:inEvent];
			}
		}
	}
}

@end // TTLog
