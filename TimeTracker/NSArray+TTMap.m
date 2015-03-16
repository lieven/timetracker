//
//  NSArray+TTMap.m
//  TimeTracker
//
//  Created by Lieven Dekeyser on 16/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import "NSArray+TTMap.h"

@implementation NSArray (TTMap)

- (NSArray *)tt_map:(id (^)(id inItem))inTransformation
{
	NSMutableArray * results = [NSMutableArray new];
	for (id item in self)
	{
		[results addObject:inTransformation(item)];
	}
	return results;
}

- (NSArray *)tt_mapUsingSelector:(SEL)inSelector
{
	NSMutableArray * results = [NSMutableArray new];
	for (id item in self)
	{
		id (*transformation)(id, SEL) = (id (*)(id, SEL))[item methodForSelector:inSelector];
		[results addObject:transformation(item, inSelector)];
	}
	return results;
}

@end // NSArray (TTMap)
