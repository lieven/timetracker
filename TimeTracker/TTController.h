//
//  TTController.h
//  TimeTracker
//
//  Created by Lieven Dekeyser on 13/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import "TTProject.h"
#import "TTTask.h"
#import "TTEvent.h"


BOOL TTEqualOrBothNil(id inObject1, id inObject2);
NSDate * TTStartOfDay(NSDate * inDate);


@interface TTController : NSObject

+ (TTController *)controller;

+ (NSString *)scriptsFolder;

@property (nonatomic, readonly, copy) NSString * currentProjectID;
@property (nonatomic, readonly, copy) NSString * currentTaskID;

@property (nonatomic, readonly, strong) NSArray * projects;
@property (nonatomic, readonly, strong) NSArray * tasks;

- (TTProject *)addProjectWithName:(NSString *)inName;
- (BOOL)saveProject:(TTProject *)inProject;

- (TTTask *)addTaskWithName:(NSString *)inName;
- (BOOL)saveTask:(TTTask *)inTask;

- (void)setCurrentProject:(NSString *)inProjectID task:(NSString *)inTaskID;
- (void)setCurrentProject:(NSString *)inProjectID task:(NSString *)inTaskID time:(NSDate *)inTime;

- (NSArray *)getEventsFrom:(NSDate *)inStartTime to:(NSDate *)inEndTime;

@end
