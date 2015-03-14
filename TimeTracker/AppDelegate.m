//
//  AppDelegate.m
//  TimeTracker
//
//  Created by Lieven Dekeyser on 13/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import "AppDelegate.h"
#import "TTController.h"
#import "TTLog.h"


@interface AppDelegate ()

@property (nonatomic, strong) NSStatusItem * statusItem;

@property (nonatomic, assign) BOOL darkModeOn;
@property (nonatomic, strong) NSMenu * menu;
@property (nonatomic, strong) NSMenuItem * projectsSubmenuItem;
@property (nonatomic, strong) NSMenu * projectsSubmenu;
@property (nonatomic, strong) NSArray * projects;
@property (nonatomic, strong) NSArray * tasks;

@property (nonatomic, assign, getter=isTracking) BOOL tracking;

@end // AppDelegate ()


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)inNotification
{
	self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	self.statusItem.image = [NSImage imageNamed:@"timer"];
	self.statusItem.highlightMode = YES;
	
	self.menu = [[NSMenu alloc] initWithTitle:@""];
	[self reloadMenu];
	
	self.statusItem.menu = self.menu;
}

- (void)applicationWillTerminate:(NSNotification *)inNotification
{
	[[TTController controller] setCurrentProject:nil task:nil];
}

- (void)addItems:(NSArray *)inItems toMenu:(NSMenu *)inMenu action:(SEL)inAction overflow:(NSString *)inOverflowTitle titleKey:(NSString *)inTitleKey update:(void (^)(id inItem, NSMenuItem * inMenuItem))inUpdateBlock
{
	NSInteger tag = 0;
	NSInteger maxItems = 5;
	
	if (inItems.count <= maxItems)
	{
		maxItems = NSIntegerMax;
	}
	
	NSMenu * menu = inMenu;
	
	for (id item in inItems)
	{
		NSString * title = [item valueForKey:inTitleKey];
		
		NSMenuItem * menuItem = [menu addItemWithTitle:title action:inAction keyEquivalent:@""];
		menuItem.tag = tag++;
		
		inUpdateBlock(item, menuItem);
		
		if (tag+1 == maxItems)
		{
			NSMenuItem * overflowMenuItem = [menu addItemWithTitle:inOverflowTitle action:nil keyEquivalent:@""];
			overflowMenuItem.submenu = [[NSMenu alloc] initWithTitle:@""];
			menu = overflowMenuItem.submenu;
			
			inUpdateBlock(nil, overflowMenuItem);
		}
	}
}

- (void)reloadMenu
{
	[self.menu removeAllItems];
	
	TTController * controller = [TTController controller];
	
	__block TTProject * currentProject = nil;
	__block TTTask * currentTask = nil;
	
	// Projects
	
	self.projectsSubmenu = [[NSMenu alloc] initWithTitle:@""];
	
	self.projects = [controller.projects sortedArrayUsingDescriptors:@[
		[NSSortDescriptor sortDescriptorWithKey:@"self.lastUse" ascending:NO],
		[NSSortDescriptor sortDescriptorWithKey:@"self.name" ascending:YES]
	]];
	
	[self addItems:self.projects toMenu:self.projectsSubmenu action:@selector(selectProject:) overflow:@"Older Projects" titleKey:@"name"
		update:^(TTProject * inProject, NSMenuItem * inMenuItem)
		{
			if (currentProject == nil && [controller.currentProjectID isEqualTo:inProject.identifier])
			{
				currentProject = inProject;
				inMenuItem.state = NSOnState;
			}
		}
	];
	
	if (self.projects.count > 0)
	{
		[self.projectsSubmenu addItem:[NSMenuItem separatorItem]];
	}
	
	[self.projectsSubmenu addItemWithTitle:@"Add Project..." action:@selector(addProject:) keyEquivalent:@""];
	
	NSString * projectsItemTitle = @"Select Project";
	if (currentProject)
	{
		projectsItemTitle = [@"Project: " stringByAppendingString:currentProject.name ?: @"<unknown>"];
	}
	
	self.projectsSubmenuItem = [[NSMenuItem alloc] initWithTitle:projectsItemTitle action:nil keyEquivalent:@""];
	self.projectsSubmenuItem.submenu = self.projectsSubmenu;
	
	[self.menu addItem:self.projectsSubmenuItem];
	
	[self.menu addItem:[NSMenuItem separatorItem]];
	
	
	if (currentProject)
	{
		self.tasks = [controller.tasks sortedArrayUsingDescriptors:@[
			[NSSortDescriptor sortDescriptorWithKey:@"self.lastUse" ascending:NO],
			[NSSortDescriptor sortDescriptorWithKey:@"self.name" ascending:YES]
		]];
		
		NSMenu * menu = self.menu;
		
		[self addItems:self.tasks toMenu:menu action:@selector(selectTask:) overflow:@"Older Tasks" titleKey:@"name"
			update:^(TTTask * inTask, NSMenuItem * inMenuItem)
			{
				if (currentTask == nil && [controller.currentTaskID isEqualTo:inTask.identifier])
				{
					currentTask = inTask;
					inMenuItem.state = NSOnState;
				}
			}
		];
		
		[self.menu addItemWithTitle:@"Add Task..." action:@selector(addTask:) keyEquivalent:@""];
		[self.menu addItem:[NSMenuItem separatorItem]];
		
		[self.menu addItemWithTitle:@"Stop Tracking" action:@selector(stopTracking:) keyEquivalent:@""];
	}
	else
	{
		self.tasks = nil;
	}
	
	[self.menu addItemWithTitle:@"Copy Today's Log" action:@selector(copyTodaysLog:) keyEquivalent:@""];
	
	[self.menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
	
	
	// Update main menu title
	
	if (currentProject)
	{
		if (currentTask)
		{
			self.statusItem.title = currentTask.name;
		}
		else
		{
			self.statusItem.title = currentProject.name;
		}
	}
	else
	{
		self.statusItem.title = @"";
	}
}

- (NSString *)truncateString:(NSString *)inString to:(NSUInteger)inMaxLength
{
	if (inString.length > inMaxLength)
	{
		return [[inString substringToIndex:inMaxLength] stringByAppendingString:@"…"];
	}
	return inString;
}

- (TTProject *)projectAtIndex:(NSUInteger)inIndex
{
	if (inIndex < self.projects.count)
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

- (TTTask *)taskAtIndex:(NSUInteger)inIndex
{
	if (inIndex < self.tasks.count)
	{
		return self.tasks[inIndex];
	}
	return nil;
}

- (void)selectTask:(NSMenuItem *)inSender
{
	TTTask * task = [self taskAtIndex:inSender.tag];
	if (task)
	{
		TTController * controller = [TTController controller];
		task.lastUse = [NSDate date];
		[controller saveTask:task];
		
		[controller setCurrentProject:controller.currentProjectID task:task.identifier];
		[self reloadMenu];
	}
}

- (void)stopTracking:(NSMenuItem *)inSender
{
	[[TTController controller] setCurrentProject:nil task:nil];
	[self reloadMenu];
}

- (NSArray *)intervalStrings:(NSArray *)inIntervals
{
	NSMutableArray * strings = [NSMutableArray new];
	for (TTInterval * interval in inIntervals)
	{
		[strings addObject:[NSString stringWithFormat:@" %@-%@",
			[NSDateFormatter localizedStringFromDate:interval.startTime dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle],
			[NSDateFormatter localizedStringFromDate:interval.endTime dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle]
		]];
	}
	return strings;
}

- (NSString *)durationString:(NSTimeInterval)inTimeInterval
{
	double seconds = inTimeInterval;
	
	double hours = floor(seconds / 3600.0);
	seconds -= 3600.0*hours;
	
	double minutes = floor(seconds / 60.0);
	seconds -= 60.0*minutes;
	
	if (hours > 0.0)
	{
		return [NSString stringWithFormat:@"%.0fh%.0fm%.0fs", hours, minutes, seconds];
	}
	else if (minutes > 0.0)
	{
		return [NSString stringWithFormat:@"%.0fm%.0fs", minutes, seconds];
	}
	else
	{
		return [NSString stringWithFormat:@"%.0fs", seconds];
	}
	
}

- (void)copyTodaysLog:(NSMenuItem *)inSender
{
	NSMutableString * logString = [NSMutableString new];
	
	NSDate * now = [NSDate date];
	
	[logString appendString:[NSDateFormatter localizedStringFromDate:now dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle]];
	[logString appendString:@"\n\n"];
	
	NSArray * events = [[TTController controller] getEventsOnDay:now];
	
	TTLog * log = [TTLog new];
	for (TTEvent * event in events)
	{
		[log addEvent:event];
	}
	
	for (TTProjectLog * projectLog in log.projectLogs.allValues)
	{
		[logString appendFormat:@"%@: %@: %@\n",
			projectLog.projectName,
			[[self intervalStrings:projectLog.intervals] componentsJoinedByString:@", "],
			[self durationString:projectLog.totalTime]
		];
		
		for (TTTaskLog * taskLog in projectLog.taskLogs.allValues)
		{
			[logString appendFormat:@"- %@: %@: %@\n",
				taskLog.taskName,
				[[self intervalStrings:taskLog.intervals] componentsJoinedByString:@", "],
				[self durationString:taskLog.totalTime]
			];
		}
		
		[logString appendString:@"\n"];
	}
	
	NSLog(@"Log:\n%@", logString);
	
	[[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[[NSPasteboard generalPasteboard] setString:logString forType:NSStringPboardType];
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
