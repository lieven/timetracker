//
//  TTController.m
//  TimeTracker
//
//  Created by Lieven Dekeyser on 13/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import "TTController.h"
#import "TTDatabase.h"

BOOL TTEqualOrBothNil(id inObject1, id inObject2)
{
	if (inObject1)
	{
		if (inObject2)
		{
			return[inObject1 isEqual:inObject2];
		}
		else
		{
			return NO;
		}
	}
	else
	{
		return (inObject2 == nil);
	}
}

NSDate * TTStartOfDay(NSDate * inDate)
{
	NSCalendar * calendar = [NSCalendar currentCalendar];
	NSDateComponents * components = [calendar components:(NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear) fromDate:inDate];
	return [calendar dateFromComponents:components];
}

NSDate * TTStartOfMonth(NSDate * inDate)
{
	NSCalendar * calendar = [NSCalendar currentCalendar];
	NSDateComponents * components = [calendar components:(NSCalendarUnitMonth | NSCalendarUnitYear) fromDate:inDate];
	return [calendar dateFromComponents:components];
}


@interface TTController ()
@property (nonatomic, strong) TTEvent * currentEvent;
@property (nonatomic, strong) TTEvent * currentProjectEvent;

@property (nonatomic, strong) TTDatabase * database;
@end // TTController ()

@implementation TTController
{
	NSMutableArray< TTProject * > * _projects;
	NSMutableArray< TTTask * > * _tasks;
}

+ (instancetype)controller
{
	static TTController * sSharedInstance = nil;
	static dispatch_once_t sOnceToken = 0;
	dispatch_once(&sOnceToken, ^{
		sSharedInstance = [self new];
	});
	return sSharedInstance;
}

+ (NSString *)applicationSupportDirectory
{
	static NSString * sPath = nil;
	static dispatch_once_t sOnceToken = 0;
	dispatch_once(&sOnceToken, ^{
		sPath = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
	});
	return sPath;
}

+ (NSString *)dataFolder
{
	static NSString * sPath = nil;
	static dispatch_once_t sOnceToken = 0;
	dispatch_once(&sOnceToken, ^{
		sPath = [[self applicationSupportDirectory] stringByAppendingPathComponent:[NSBundle mainBundle].bundleIdentifier];
		NSFileManager *fm = [NSFileManager defaultManager];
		if (! [fm fileExistsAtPath:sPath])
		{
			NSError * error = nil;
			if (! [fm createDirectoryAtPath:sPath withIntermediateDirectories:YES attributes:nil error:&error])
			{
				NSLog(@"Could not create data folder: %@", sPath);
			}
		}
	});
	return sPath;
}

+ (NSString *)scriptsFolder
{
	static NSString * sPath = nil;
	static dispatch_once_t sOnceToken = 0;
	dispatch_once(&sOnceToken, ^{
		sPath = [[self dataFolder] stringByAppendingPathComponent:@"Scripts"];
		NSFileManager * fm = [NSFileManager defaultManager];
		if (! [fm fileExistsAtPath:sPath])
		{
			NSString * defaultScripts = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"DefaultScripts"];
			
			NSError * error = nil;
			if (! [fm copyItemAtPath:defaultScripts toPath:sPath error:&error])
			{
				NSLog(@"Could not copy default scripts");
			}
		}
	});
	return sPath;
}

+ (NSString *)databasePath
{
	static NSString * sPath = nil;
	static dispatch_once_t sOnceToken = 0;
	dispatch_once(&sOnceToken, ^{
		sPath = [[self dataFolder] stringByAppendingPathComponent:@"TimeTracker.sqlite"];
	});
	return sPath;
}

+ (void)migrate
{
	static dispatch_once_t sOnceToken = 0;
	dispatch_once(&sOnceToken, ^{
	
		NSString * newPath = [self databasePath];
		NSFileManager * fm = [NSFileManager defaultManager];
		if (! [fm fileExistsAtPath:newPath])
		{
			NSString * oldPath = [[self applicationSupportDirectory] stringByAppendingPathComponent:@"TimeTracker.sqlite"];
			if ([fm fileExistsAtPath:oldPath])
			{
				NSError * error = nil;
				if (! [fm moveItemAtPath:oldPath toPath:newPath error:&error])
				{
					NSLog(@"Could not move database from %@ to %@", oldPath, newPath);
				}
			}
		}
	});
}

- (instancetype)init
{
	if ((self = [super init]))
	{
		[self.class migrate];
		
		self.database = [[TTDatabase alloc] initWithPath:[self.class databasePath]];
		self.currentEvent =  [self.database getLastEvent];
	}
	return self;
}

- (void)setCurrentEvent:(TTEvent *)currentEvent
{
	_currentEvent = currentEvent;
	
	self.currentProjectEvent = currentEvent ? [self.database getProjectEventFor:currentEvent] : nil;
}

- (NSArray< TTProject * > *)projects
{
	if (_projects == nil)
	{
		_projects = [[self.database getProjects] mutableCopy];
	}
	return _projects;
}

- (TTProject *)addProjectWithName:(NSString *)inName
{
	TTProject * project = [self.database addProjectWithName:inName];
	if (project)
	{
		[_projects addObject:project];
	}
	return project;
}

- (BOOL)saveProject:(TTProject *)inProject
{
	return [self.database saveProject:inProject];
}

- (NSArray< TTTask * > *)tasks
{
	NSString * currentProjectID = self.currentEvent.projectID;
	if (_tasks == nil && currentProjectID)
	{
		_tasks = [[self.database getTasks:currentProjectID] mutableCopy];
	}
	return _tasks;
	
}

- (TTTask *)addTaskWithName:(NSString *)inName
{
	NSString * currentProjectID = self.currentEvent.projectID;
	if (currentProjectID)
	{
		TTTask * task = [self.database addTaskWithName:inName project:currentProjectID];
		if (task)
		{
			[_tasks addObject:task];
		}
	}
	return nil;
}

- (BOOL)saveTask:(TTTask *)inTask
{
	return [self.database saveTask:inTask];
}

- (void)setCurrentProject:(NSString *)inProjectID task:(NSString *)inTaskID time:(NSDate *)inTime truncate:(BOOL)inTruncateEvents
{
	NSString * currentProjectID = self.currentEvent.projectID;
	if (! TTEqualOrBothNil(currentProjectID, inProjectID))
	{
		_tasks = nil;
	}
	
	BOOL added = [self.database addEvent:inTime project:inProjectID task:inTaskID truncate:inTruncateEvents];
	if (added)
	{
		self.currentEvent = [self.database getLastEvent];
	}
}

- (NSArray< TTEvent * > *)getEventsFrom:(NSDate *)inStartTime to:(NSDate *)inEndTime
{
	return [self.database getEventsFrom:inStartTime to:inEndTime];
}

@end // TTController
