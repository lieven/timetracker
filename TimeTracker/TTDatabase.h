//
//  TTDatabase.h
//  TimeTracker
//
//  Created by Lieven Dekeyser on 13/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import "TTProject.h"
#import "TTEvent.h"
#import "TTTask.h"


@interface TTDatabase : NSObject

- (instancetype)init;

- (NSArray *)getProjects;

- (TTProject *)addProjectWithName:(NSString *)inName;

- (BOOL)saveProject:(TTProject *)inProject;

- (NSArray *)getTasks:(NSString *)inProjectID;

- (TTTask *)addTaskWithName:(NSString *)inName project:(NSString *)inProjectID;

- (BOOL)saveTask:(TTTask *)inTask;

- (BOOL)addEvent:(NSDate *)inTime project:(NSString *)inProjectID task:(NSString *)inTaskID;

- (NSArray *)getEventsFrom:(NSDate *)inStartTime to:(NSDate *)inEndTime;

@end
