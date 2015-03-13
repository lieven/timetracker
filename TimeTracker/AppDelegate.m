//
//  AppDelegate.m
//  TimeTracker
//
//  Created by Lieven Dekeyser on 13/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import "AppDelegate.h"
#import "TTController.h"

@interface AppDelegate ()

@property (nonatomic, strong) NSStatusItem * statusItem;

@property (nonatomic, assign) BOOL darkModeOn;
@property (nonatomic, strong) NSMenu * menu;
@property (nonatomic, strong) NSMenuItem * projectsSubmenuItem;
@property (nonatomic, strong) NSMenu * projectsSubmenu;
@property (nonatomic, strong) NSArray * projects;

@property (nonatomic, assign, getter=isTracking) BOOL tracking;

@end // AppDelegate ()


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)inNotification
{
	self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	self.statusItem.image = [NSImage imageNamed:@"timer"];
	self.statusItem.highlightMode = YES;
	
	self.menu = [[NSMenu alloc] initWithTitle:@"TimeTracker"];
	[self reloadMenu];
	
	self.statusItem.menu = self.menu;
}

- (void)applicationWillTerminate:(NSNotification *)inNotification
{
	// Insert code here to tear down your application
}

- (void)reloadMenu
{
	[self.menu removeAllItems];
	
	// Tasks
	// -
	// Projects
	// Stop tracking
	// -
	// Quit
	
	TTController * controller = [TTController controller];
	
	if (controller.currentProjectID)
	{
		NSMenuItem * titleItem = [self.menu addItemWithTitle:@"Tasks" action:nil keyEquivalent:@""];
		titleItem.enabled = NO;
		
		[self.menu addItemWithTitle:@"Add Task..." action:@selector(addTask:) keyEquivalent:@""];
	}
	
	
	self.projectsSubmenu = [[NSMenu alloc] initWithTitle:@""];
	
	self.projects = [controller.projects sortedArrayUsingDescriptors:@[
		[NSSortDescriptor sortDescriptorWithKey:@"self.lastUse" ascending:NO],
		[NSSortDescriptor sortDescriptorWithKey:@"self.name" ascending:YES]
	]];
	
	NSInteger projectTag = 0;
	TTProject * currentProject = nil;
	
	for (TTProject * project in self.projects)
	{
		NSMenuItem * projectMenuItem = [self.projectsSubmenu addItemWithTitle:project.name action:@selector(selectProject:) keyEquivalent:@""];
		projectMenuItem.tag = projectTag++;
		
		if ([controller.currentProjectID isEqualTo:project.identifier])
		{
			projectMenuItem.state = NSOnState;
			currentProject = project;
		}
	}
	
	if (projectTag > 0)
	{
		[self.projectsSubmenu addItem:[NSMenuItem separatorItem]];
	}
	
	[self.projectsSubmenu addItemWithTitle:@"Add Project..." action:@selector(addProject:) keyEquivalent:@""];
	
	NSString * projectsItemTitle = @"Select Project";
	if (currentProject)
	{
		projectsItemTitle = [@"Project: " stringByAppendingString:currentProject.name ?: @"<unknown>"];
		self.statusItem.title = currentProject.name;
	}
	else
	{
		self.statusItem.title = @"...";
	}
	
	
	self.projectsSubmenuItem = [[NSMenuItem alloc] initWithTitle:projectsItemTitle action:nil keyEquivalent:@""];
	self.projectsSubmenuItem.submenu = self.projectsSubmenu;
	
	[self.menu addItem:self.projectsSubmenuItem];
	
	if (currentProject)
	{
		[self.menu addItemWithTitle:@"Stop Tracking" action:@selector(stopTracking:) keyEquivalent:@""];
	}
	
	[self.menu addItem:[NSMenuItem separatorItem]];
	
	[self.menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
	
}

- (NSString *)truncateString:(NSString *)inString to:(NSUInteger)inMaxLength
{
	if (inString.length > inMaxLength)
	{
		return [[inString substringToIndex:inMaxLength] stringByAppendingString:@"…"];
	}
	return inString;
}

- (TTProject *)projectAtIndex:(NSInteger)inIndex
{
	if (inIndex >= 0 && inIndex < self.projects.count)
	{
		return self.projects[inIndex];
	}
	return nil;
}

- (void)selectProject:(NSMenuItem *)inSender
{
	TTProject * project = [self projectAtIndex:inSender.tag];
	if (project)
	{
		TTController * controller = [TTController controller];
		
		project.lastUse = [NSDate date];
		[controller saveProject:project];
		
		[controller setCurrentProject:project.identifier task:nil];
		
		[self reloadMenu];
	}
}

- (void)addProject:(NSMenuItem *)inSender
{
	__weak typeof(self) weakSelf = self;
	
	[self showInputAlert:@"Add Project" confirmButton:@"Add"
		completion:^(NSString *inInputText)
		{
			if (inInputText)
			{
				if ([[TTController controller] addProjectWithName:inInputText])
				{
					[weakSelf reloadMenu];
				}
				else
				{
					NSLog(@"Could not add project with name: %@", inInputText);
				}
			}
		}
	];

	
}

- (void)stopTracking:(NSMenuItem *)inSender
{
	[[TTController controller] setCurrentProject:nil task:nil];
	[self reloadMenu];
}

- (void)addTask:(NSMenuItem *)inSender
{
	__weak typeof(self) weakSelf = self;
	
	[self showInputAlert:@"Add Task" confirmButton:@"Add"
		completion:^(NSString *inInputText)
		{
			[[TTController controller] addTaskWithName:inInputText];
			[weakSelf reloadMenu];
		}
	];
}


- (void)showInputAlert:(NSString *)inMessage confirmButton:(NSString *)inConfirmButton completion:(void (^)(NSString * inInputText))inCompletionBlock
{
	NSAlert * alert = [NSAlert alertWithMessageText:inMessage defaultButton:inConfirmButton alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@""];
	
	NSTextField * textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300.0, 24.0)];
	textField.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	alert.accessoryView = textField;
	
	NSString * resultText = nil;
	
	NSInteger button = [alert runModal];
	switch (button)
	{
		case NSAlertDefaultReturn:
		{
			[textField validateEditing];
			resultText = textField.stringValue;
			break;
		}
		default:
		{
			// Canceled
			break;
		}
	}
	
	if (inCompletionBlock)
	{
		inCompletionBlock(resultText);
	}
}

@end // AppDelegate
