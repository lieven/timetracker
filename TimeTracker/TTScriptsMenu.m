//
//  TTScriptsMenu.m
//  TimeTracker
//
//  Created by Lieven Dekeyser on 16/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import "TTScriptsMenu.h"


@interface TTScriptsMenu ()
@property (nonatomic, copy) NSString * folder;
@property (nonatomic, strong) NSArray * scripts;
@end // TTScriptsMenu ()

@implementation TTScriptsMenu

- (instancetype)initWithFolder:(NSString *)inFolderPath
{
	if ((self = [super initWithTitle:@"Scripts"]))
	{
		self.folder = inFolderPath;
		self.delegate = self;
	}
	return self;
}

- (void)menuNeedsUpdate:(NSMenu*)inMenu
{
	[inMenu removeAllItems];
	
	NSMutableArray * scripts = [NSMutableArray new];
	
	NSFileManager * fm = [NSFileManager defaultManager];
	
	NSString * scriptsFolder = self.folder;
	
	NSError * error = nil;
	NSArray * filenames = [fm contentsOfDirectoryAtPath:scriptsFolder error:&error];
	for (NSString * filename in filenames)
	{
		if ([filename.pathExtension isEqualToString:@"sh"] || [filename.pathExtension isEqualToString:@"swift"])
		{
			NSMenuItem * menuItem = [inMenu addItemWithTitle:[filename stringByDeletingPathExtension] action:@selector(runScript:) keyEquivalent:@""];
			menuItem.target = self;
			menuItem.tag = scripts.count;
			[scripts addObject:[scriptsFolder stringByAppendingPathComponent:filename]];
		}
	}
	
	self.scripts = scripts;
	
	if (scripts.count > 0)
	{
		[self addItem:[NSMenuItem separatorItem]];
	}
	
	[self addItemWithTitle:@"Show Scripts in Finder" action:@selector(openScriptsFolder:) keyEquivalent:@""].target = self;
}

- (void)runScript:(NSMenuItem *)inMenuItem
{
	NSString * script = self.scripts[inMenuItem.tag];
	if (self.onRunScript)
	{
		self.onRunScript(script);
	}
}

- (void)openScriptsFolder:(NSMenuItem *)inMenuItem
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:self.folder isDirectory:YES]];
}

@end
