//
//  NSArray+TTMap.h
//  TimeTracker
//
//  Created by Lieven Dekeyser on 16/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (TTMap)

- (NSArray *)tt_map:(id (^)(id inItem))inTransformation;
- (NSArray *)tt_mapUsingSelector:(SEL)inSelector;

@end // NSArray (TTMap)
