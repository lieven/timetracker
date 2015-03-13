//
//  TTProject.h
//  TimeTracker
//
//  Created by Lieven Dekeyser on 13/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TTProject : NSObject

@property (nonatomic, copy) NSString * identifier;
@property (nonatomic, copy) NSString * name;
@property (nonatomic, copy) NSDate * lastUse;

@end // TTProject
