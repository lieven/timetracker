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
		
		[db executeUpdate:@"CREATE TABLE IF NOT EXISTS Tasks (`identifier` INTEGER PRIMARY KEY AUTOINCREMENT, `name` VARCHAR(255) UNIQUE, `project` INT, `lastUse` REAL);"];
		
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


- (NSArray *)getTasks:(NSString *)inProjectID
{
	__block NSMutableArray * tasks = nil;
	
	if (inProjectID)
	{
		[self.queue inDatabase:^(FMDatabase *db) {
			tasks = [NSMutableArray new];
			
			FMResultSet * results = [db executeQuery:@"SELECT * FROM Tasks WHERE project=?", inProjectID];
			while ([results next])
			{
				TTTask * task = [TTTask new];
				task.identifier = [results stringForColumn:@"identifier"];
				task.project = [results stringForColumn:@"project"];
				task.name = [results stringForColumn:@"name"];
				task.lastUse = [results dateForColumn:@"lastUse"];
				[tasks addObject:task];
			}
		}];
	}
	
	return tasks;
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
				task = [TTTask new];
				task.identifier = [@(db.lastInsertRowId) stringValue];
				task.project = inProjectID;
				task.name = inName;
				task.lastUse = lastUse;
			}
		}];
	}
	
	return task;
}

- (BOOL)saveTask:(TTTask *)inTask
{
	__block BOOL saved = NO;
	if (inTask.identifier)
	{
		[self.queue inDatabase:^(FMDatabase *db) {
			saved = [db executeUpdate:@"UPDATE Tasks SET name=?, lastUse=? WHERE identifier=?", inTask.name, inTask.lastUse, inTask.identifier];
		}];
	}
	return saved;
}

- (BOOL)addEvent:(NSDate *)inTime project:(NSString *)inProjectID task:(NSString *)inTaskID
{
	__block BOOL inserted = YES;
	[self.queue inDatabase:^(FMDatabase *db) {
		inserted = [db executeUpdate:@"INSERT INTO Events (`project`, `task`, `timestamp`) VALUES(?, ?, ?);", inProjectID, inTaskID, inTime];
	}];
	return inserted;
}


- (NSArray *)getEventsFrom:(NSDate *)inStartTime to:(NSDate *)inEndTime
{
	NSMutableArray * events = [NSMutableArray new];
	
	[self.queue inDatabase:^(FMDatabase *db) {
		FMResultSet * results = [db executeQuery:@"SELECT e.identifier, e.timestamp, e.project AS projectID, p.name AS projectName, e.task AS taskID, t.name AS taskName FROM Events e LEFT JOIN Projects p ON e.project=p.identifier LEFT JOIN Tasks t ON e.task=t.identifier WHERE `timestamp` >= ? AND `timestamp` <= ?", inStartTime, inEndTime];
		while ([results next])
		{
			TTEvent * event = [TTEvent new];
			event.identifier = [results stringForColumn:@"identifier"];
			event.time = [results dateForColumn:@"timestamp"];
			event.projectID = [results stringForColumn:@"projectID"];
			event.projectName = [results stringForColumn:@"projectName"];
			event.taskID = [results stringForColumn:@"taskID"];
			event.taskName = [results stringForColumn:@"taskName"];
			[events addObject:event];
		}
	}];
	
	return events;
}

@end
