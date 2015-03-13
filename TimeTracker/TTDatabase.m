//
//  TTDatabase.m
//  TimeTracker
//
//  Created by Lieven Dekeyser on 13/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import "TTDatabase.h"
#import "FMDatabaseQueue.h"
#import "FMDatabase.h"

@interface TTDatabase ()
@property (nonatomic, strong) FMDatabaseQueue * queue;
@end // TTDatabase ()


@implementation TTDatabase

+ (NSString *)applicationSupportDirectory
{
	static NSString * sPath = nil;
	static dispatch_once_t sOnceToken = 0;
	dispatch_once(&sOnceToken, ^{
		sPath = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
	});
	return sPath;
}

+ (NSString *)databasePath
{
	static NSString * sPath = nil;
	static dispatch_once_t sOnceToken = 0;
	dispatch_once(&sOnceToken, ^{
		sPath = [[self applicationSupportDirectory] stringByAppendingPathComponent:@"TimeTracker.sqlite"];
	});
	return sPath;
}

- (instancetype)init
{
	if ((self = [super init]))
	{
		self.queue = [[FMDatabaseQueue alloc] initWithPath:[self.class databasePath]];
		if (! self.queue)
		{
			return nil;
		}
		
		[self createTables];
		
	}
	return self;
}

- (void)createTables
{
	[self.queue inDatabase:^(FMDatabase *db) {
		
		db.traceExecution = YES;
		
		[db executeUpdate:@"CREATE TABLE IF NOT EXISTS Projects (`identifier` INTEGER PRIMARY KEY AUTOINCREMENT, `name` VARCHAR(255) UNIQUE, lastUse REAL);"];
		
		[db executeUpdate:@"CREATE TABLE IF NOT EXISTS Tasks (`identifier` INTEGER PRIMARY KEY AUTOINCREMENT, `name` VARCHAR(255), `project` INT, `lastUse` REAL);"];
		
		[db executeUpdate:@"CREATE TABLE IF NOT EXISTS Events (`identifier` INTEGER PRIMARY KEY AUTOINCREMENT, `project` INT DEFAULT NULL, `task` INT DEFAULT NULL, `timestamp` REAL);"];
		
	}];
}

- (void)dealloc
{
	[self.queue close];
	self.queue = nil;
}

- (NSArray *)getProjects
{
	__block NSMutableArray * projects = [NSMutableArray new];
	
	[self.queue inDatabase:^(FMDatabase *db) {
		
		
		FMResultSet * results = [db executeQuery:@"SELECT * FROM Projects;"];
		while ([results next])
		{
			TTProject * project = [TTProject new];
			project.identifier = [results stringForColumn:@"identifier"];
			project.name = [results stringForColumn:@"name"];
			project.lastUse = [results dateForColumn:@"lastUse"];
			
			[projects addObject:project];
		}
	}];
	
	return projects;
}

- (TTProject *)addProjectWithName:(NSString *)inName
{
	__block TTProject * project = nil;
	
	[self.queue inDatabase:^(FMDatabase *db) {
		
		NSDate * lastUse = [NSDate date];
		
		BOOL inserted = [db executeUpdate:@"INSERT INTO Projects (name, lastUse) VALUES(?, ?);", inName, lastUse];
		if (inserted)
		{
			project = [TTProject new];
			project.identifier = [@([db lastInsertRowId]) stringValue];
			project.name = inName;
			project.lastUse = lastUse;
		}
		
	}];
	
	return project;
}

- (BOOL)saveProject:(TTProject *)inProject
{
	__block BOOL saved = NO;
	
	if (inProject.identifier)
	{
		[self.queue inDatabase:^(FMDatabase *db) {
			saved = [db executeUpdate:@"UPDATE Projects SET name=?, lastUse=? WHERE identifier=?", inProject.name, inProject.lastUse, inProject.identifier];
		}];
	}
	
	return saved;
}


- (TTTask *)addTaskWithName:(NSString *)inName project:(NSString *)inProjectID
{
	__block TTTask * task = nil;
	
	if (inName && inProjectID)
	{
		[self.queue inDatabase:^(FMDatabase *db) {
			
			NSDate * lastUse = [NSDate date];
			
			BOOL inserted = [db executeUpdate:@"INSERT INTO Tasks (name, project, lastUse) VALUES(?, ?, ?)", inName, inProjectID, lastUse];
			if (inserted)
			{
				TTTask * task = [TTTask new];
				task.identifier = [@(db.lastInsertRowId) stringValue];
				task.project = inProjectID;
				task.name = inName;
				task.lastUse = lastUse;
			}
		}];
	}
	
	return task;
}

- (TTEvent *)addEvent:(NSDate *)inTime project:(NSString *)inProjectID task:(NSString *)inTaskID
{
	__block TTEvent * event = nil;
	[self.queue inDatabase:^(FMDatabase *db) {
		BOOL inserted = [db executeUpdate:@"INSERT INTO Events (`project`, `task`, `timestamp`) VALUES(?, ?, ?);", inProjectID, inTaskID, inTime];
		if (inserted)
		{
			event = [TTEvent new];
			event.identifier = [@(db.lastInsertRowId) stringValue];
			event.time = inTime;
			event.project = inProjectID;
			event.task = inTaskID;
		}
	}];
	return event;
}


- (NSArray *)getEventsFrom:(NSDate *)inStartTime to:(NSDate *)inEndTime
{
	NSMutableArray * events = [NSMutableArray new];
	
	[self.queue inDatabase:^(FMDatabase *db) {
		FMResultSet * results = [db executeQuery:@"SELECT * FROM Events WHERE `timestamp` >= ? AND `timestamp` <= ?", inStartTime, inEndTime];
		while ([results next])
		{
			TTEvent * event = [TTEvent new];
			event.identifier = [results stringForColumn:@"identifier"];
			event.time = [results dateForColumn:@"timestamp"];
			event.project = [results stringForColumn:@"project"];
			event.task = [results stringForColumn:@"task"];
			[events addObject:event];
		}
	}];
	
	return events;
}

@end
