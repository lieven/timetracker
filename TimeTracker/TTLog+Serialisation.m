//
//  TTLog+Serialisation.m
//  TimeTracker
//
//  Created by Lieven Dekeyser on 16/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import "TTLog+Serialisation.h"
#import "NSArray+TTMap.h"

@implementation TTInterval (Serialisation)

+ (NSDateFormatter *)dateFormatter
{
	static NSDateFormatter * sDateFormatter = nil;
	static dispatch_once_t sOnceToken = 0;
	dispatch_once(&sOnceToken, ^{
		sDateFormatter = [NSDateFormatter new];
		sDateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
	});
	return sDateFormatter;
}

- (NSDictionary *)toDictionary
{
	NSDateFormatter * dateFormatter = [self.class dateFormatter];
	return @{
		@"start": self.startTime ? [dateFormatter stringFromDate:self.startTime] : [NSNull null],
		@"end": self.endTime ? [dateFormatter stringFromDate:self.endTime] : [NSNull null]
	};
}

@end // TTInterval (Serialisation)


@implementation TTProjectLog (Serialisation)

- (NSDictionary *)toDictionary
{
	return @{
		@"project": self.projectName ?: [NSNull null],
		@"intervals": self.intervals ? [self.intervals tt_mapUsingSelector:@selector(toDictionary)] : @[],
		@"duration": @(self.totalTime),
		@"tasks": [self.taskLogs.allValues tt_map:^id(TTTaskLog * inTaskLog) {
			return @{
				@"name": inTaskLog.taskName ?: [NSNull null],
				@"intervals": inTaskLog.intervals ? [inTaskLog.intervals tt_mapUsingSelector:@selector(toDictionary)] : @[],
				@"duration": @(inTaskLog.totalTime)
			};
		}],
	};
}

@end // TTProjectLog (Serialisation)



@implementation TTLog (Serialisation)

- (NSString *)toString
{
	return nil;
}

- (NSArray *)toDictionaries
{
	return [self.projectLogs.allValues tt_mapUsingSelector:@selector(toDictionary)];
}


@end
