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

#define SELECT_EVENT_QUERY @"SELECT e.identifier, e.timestamp, e.project AS projectID, p.name AS projectName, e.task AS taskID, t.name AS taskName FROM Events e LEFT JOIN Projects p ON e.project=p.identifier LEFT JOIN Tasks t ON e.task=t.identifier"


@interface TTEvent (Database)
+ (TTEvent *)eventWithResultSet:(FMResultSet *)inResultSet;
@end // TTEvent (Database)

@interface TTDatabase ()
@property (nonatomic, strong) FMDatabaseQueue * queue;
@end // TTDatabase ()


@implementation TTDatabase

- (instancetype)initWithPath:(NSString *)inPath
{
	if ((self = [super init]))
	{
		self.queue = [[FMDatabaseQueue alloc] initWithPath:inPath];
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
	__block NSMutableArray< TTProject * > * projects = [NSMutableArray new];
	
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


- (NSArray< TTTask * > *)getTasks:(NSString *)inProjectID
{
	__block NSMutableArray< TTTask * > * tasks = nil;
	
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

- (BOOL)addEvent:(NSDate *)inTime project:(NSString *)inProjectID task:(NSString *)inTaskID truncate:(BOOL)inTruncate
{
	__block BOOL inserted = YES;
    [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if (inTruncate)
        {
            [db executeUpdate:@"DELETE FROM Events WHERE `timestamp` >= ?;", inTime];
        }
        inserted = [db executeUpdate:@"INSERT INTO Events (`project`, `task`, `timestamp`) VALUES(?, ?, ?);", inProjectID, inTaskID, inTime];
    }];
	return inserted;
}


- (NSArray< TTEvent * > *)getEventsFrom:(NSDate *)inStartTime to:(NSDate *)inEndTime
{
    if (inStartTime == nil)
    {
        return nil;
    }
    
	NSMutableArray< TTEvent * > * events = [NSMutableArray new];
    
	[self.queue inDatabase:^(FMDatabase *db) {
        NSString * query = SELECT_EVENT_QUERY " WHERE `timestamp` >= ?";
        if (inEndTime)
        {
            query = [query stringByAppendingString:@" AND `timestamp` <= ?"];
        }
        query = [query stringByAppendingString:@" ORDER BY `timestamp`"];
		FMResultSet * results = [db executeQuery:query, inStartTime, inEndTime];
		while ([results next])
		{
			TTEvent * event = [TTEvent eventWithResultSet:results];
            if (event)
            {
                [events addObject:event];
            }
		}
	}];
	
	return events;
}

- (TTEvent *)getLastEvent
{
    NSString * query = SELECT_EVENT_QUERY " ORDER BY `timestamp` DESC LIMIT 1";
    return [self getEventWithQuery:query args:nil];
}


- (TTEvent *)getProjectEventFor:(TTEvent *)inEvent
{
    NSString * projectID = inEvent.projectID;
    NSDate * timestamp = inEvent.time;
    if (projectID == nil || timestamp == nil)
    {
        return nil;
    }
    
    if (inEvent.taskID == nil)
    {
        return inEvent;
    }
    
    NSString * query = SELECT_EVENT_QUERY " WHERE e.project=? AND e.timestamp < ? ORDER BY e.timestamp DESC LIMIT 1;";
    return [self getEventWithQuery:query args:@[ projectID, timestamp ]];
}

- (TTEvent *)getEventWithQuery:(NSString *)inQuery args:(NSArray *)inArgs
{
    __block TTEvent * result = nil;
    [self.queue inDatabase:^(FMDatabase *db) {
		FMResultSet * resultSet = [db executeQuery:inQuery withArgumentsInArray:inArgs ?: @[]];
        if ([resultSet next])
        {
            result = [TTEvent eventWithResultSet:resultSet];
            [resultSet close];
        }
    }];
    return result;
}

@end // TTDatabase


@implementation TTEvent (Database)

+ (TTEvent *)eventWithResultSet:(FMResultSet *)inResultSet
{
    NSString * identifier = [inResultSet stringForColumn:@"identifier"];
    if (identifier == nil)
    {
        return nil;
    }
    
    TTEvent * event = [TTEvent new];
    event.identifier = identifier;
    event.time = [inResultSet dateForColumn:@"timestamp"];
    event.projectID = [inResultSet stringForColumn:@"projectID"];
    event.projectName = [inResultSet stringForColumn:@"projectName"];
    event.taskID = [inResultSet stringForColumn:@"taskID"];
    event.taskName = [inResultSet stringForColumn:@"taskName"];
    return event;
}

@end // TTEvent (Database)
