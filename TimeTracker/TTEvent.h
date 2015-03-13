//
//  TTEvent.h
//  TimeTracker
//
//  Created by Showpad on 13/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TTEvent : NSObject

@property (nonatomic, copy) NSString * identifier;
@property (nonatomic, copy) NSString * project;
@property (nonatomic, copy) NSString * task;
@property (nonatomic, copy) NSDate * time;

@end // TTEvent
