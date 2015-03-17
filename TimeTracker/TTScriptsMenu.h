//
//  TTScriptsMenu.h
//  TimeTracker
//
//  Created by Lieven Dekeyser on 16/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TTScriptsMenu : NSMenu< NSMenuDelegate >

- (instancetype)initWithFolder:(NSString *)inFolderPath;

@property (nonatomic, copy) void (^onRunScript)(NSString * inScriptPath);

@end // TTScriptsMenu
