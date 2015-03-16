//
//  TTLog+Serialisation.h
//  TimeTracker
//
//  Created by Lieven Dekeyser on 16/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import "TTLog.h"


@interface TTInterval (Serialisation)

- (NSDictionary *)toDictionary;

@end // TTInterval (Serialisation)


@interface TTProjectLog (Serialisation)

- (NSDictionary *)toDictionary;

@end // TTProjectLog (Serialisation)



@interface TTLog (Serialisation)

- (NSString *)toString;

- (NSArray *)toDictionaries;

@end
