//
//  AppDelegate.m
//  TimeTracker
//
//  Created by Lieven Dekeyser on 13/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import "AppDelegate.h"
#import "TTController.h"
#import "TTLog+Serialisation.h"
#import "TTScriptsMenu.h"



@interface AppDelegate ()< NSMenuDelegate >

@property (nonatomic, strong) NSStatusItem * statusItem;

@property (nonatomic, assign) BOOL darkModeOn;
@property (nonatomic, strong) NSMenu * menu;
@property (nonatomic, strong) NSMenu * projectsSubmenu;
@property (nonatomic, strong) NSArray * projects;
@property (nonatomic, strong) NSArray * tasks;

@property (nonatomic, assign, getter=isTracking) BOOL tracking;

@property (nonatomic, weak) NSMenuItem * currentProjectMenuItem;
@property (nonatomic, weak) NSMenuItem * currentTaskMenuItem;

@property (nonatomic, strong) NSArray * projectMenuItems;
@property (nonatomic, strong) NSArray * taskMenuItems;
@property (nonatomic, strong) NSMenuItem * summaryItem;
@property (nonatomic, strong) NSMenuItem * monthlySummaryItem;
@property (nonatomic, strong) NSMenuItem * stopTrackingItem;
@property (nonatomic, assign) BOOL optionKeyDown;
@property (nonatomic, strong) NSTimer * optionKeyTimer;

@property (nonatomic, strong) TTScriptsMenu * scriptsMenu;

@end // AppDelegate ()


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)inNotification
{
    NSImage *statusItemImage = [NSImage imageNamed:@"timer"];
    [statusItemImage setTemplate:YES];
    
	self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.image = statusItemImage;
	self.statusItem.highlightMode = YES;
	
	self.menu = [[NSMenu alloc] initWithTitle:@""];
	self.menu.delegate = self;
	
	__weak typeof(self) weakSelf = self;
	
	self.scriptsMenu = [[TTScriptsMenu alloc] initWithFolder:[TTController scriptsFolder]];
	self.scriptsMenu.onRunScript = ^(NSString * inScriptPath)
	{
		[weakSelf runScriptWithTodaysLog:inScriptPath];
	};
	
	
	[self reloadMenu];
	
	self.statusItem.menu = self.menu;
}

- (void)applicationWillTerminate:(NSNotification *)inNotification
{
	[[TTController controller] setCurrentProject:nil task:nil time:[NSDate date] truncate:NO];
}

- (NSArray *)addItems:(NSArray *)inItems toMenu:(NSMenu *)inMenu action:(SEL)inAction overflow:(NSString *)inOverflowTitle titleKey:(NSString *)inTitleKey update:(void (^)(id inItem, NSMenuItem * inMenuItem))inUpdateBlock
{
	NSInteger tag = 0;
	NSInteger maxItems = 5;
	
	if (inItems.count <= maxItems)
	{
		maxItems = NSIntegerMax;
	}
	
	NSMenu * menu = inMenu;
	
	NSMutableArray * menuItems = [NSMutableArray new];;
	
	for (id item in inItems)
	{
		NSString * title = [item valueForKey:inTitleKey];
		
		NSMenuItem * menuItem = [menu addItemWithTitle:title action:inAction keyEquivalent:@""];
		menuItem.tag = tag++;
		
		[menuItems addObject:menuItem];
		
		inUpdateBlock(item, menuItem);
		
		if (tag+1 == maxItems)
		{
			NSMenuItem * overflowMenuItem = [menu addItemWithTitle:inOverflowTitle action:nil keyEquivalent:@""];
			overflowMenuItem.submenu = [[NSMenu alloc] initWithTitle:@""];
			menu = overflowMenuItem.submenu;
			
			inUpdateBlock(nil, overflowMenuItem);
		}
	}
	
	return menuItems;
}

+ (NSAttributedString *)attributedTitle:(NSString *)inTitle time:(NSTimeInterval)inTimeInterval
{
	NSString * title = [inTitle stringByAppendingFormat:@" (%@)", [self durationString:inTimeInterval]];
	
	NSMutableAttributedString * attributedTitle = [[NSMutableAttributedString alloc] initWithString:title attributes:@{ NSFontAttributeName: [NSFont menuFontOfSize:0.0] }];
	[attributedTitle addAttribute:NSForegroundColorAttributeName value:[NSColor lightGrayColor] range:NSMakeRange(inTitle.length, title.length - inTitle.length)];
	return attributedTitle;
}

- (void)reloadMenuDelayed
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadMenu) object:nil];
    [self performSelector:@selector(reloadMenu) withObject:nil afterDelay:0.1];
}

- (void)reloadMenu
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(reloadMenu) object:nil];
    
	[self.menu removeAllItems];
	
	TTController * controller = [TTController controller];
	
    TTEvent * currentEvent = controller.currentEvent;
    NSString * currentProjectID = currentEvent.projectID;
    NSString * currentTaskID = currentEvent.taskID;
    
    
	// Projects
	
	__weak typeof(self) weakSelf = self;
	
	self.projectsSubmenu = [[NSMenu alloc] initWithTitle:@""];
	
	self.projects = [controller.projects sortedArrayUsingDescriptors:@[
		[NSSortDescriptor sortDescriptorWithKey:@"self.lastUse" ascending:NO],
		[NSSortDescriptor sortDescriptorWithKey:@"self.name" ascending:YES]
	]];
	
	self.projectMenuItems = [self addItems:self.projects toMenu:self.projectsSubmenu action:@selector(selectProject:) overflow:@"Older Projects" titleKey:@"name"
		update:^(TTProject * inProject, NSMenuItem * inMenuItem)
		{
			if ([currentProjectID isEqualTo:inProject.identifier])
			{
				inMenuItem.state = NSOnState;
				inMenuItem.action = nil;
			}
			else if (weakSelf.optionKeyDown)
			{
				inMenuItem.title = [inMenuItem.title stringByAppendingString:@"..."];
			}
		}
	];
	
	if (self.projects.count > 0)
	{
		[self.projectsSubmenu addItem:[NSMenuItem separatorItem]];
	}
	
	[self.projectsSubmenu addItemWithTitle:@"Add Project..." action:@selector(addProject:) keyEquivalent:@""];
	
	
	NSMenuItem * projectsSubmenuItem = [[NSMenuItem alloc] initWithTitle:@"Select Project" action:nil keyEquivalent:@""];
	projectsSubmenuItem.submenu = self.projectsSubmenu;
	
	[self.menu addItem:projectsSubmenuItem];
	
	self.currentProjectMenuItem = projectsSubmenuItem;
	
	[self.menu addItem:[NSMenuItem separatorItem]];
	
	
	if (currentProjectID)
	{
        projectsSubmenuItem.title = currentEvent.projectName ?: @"Untitled Project";
		NSArray< TTTask * > * tasks = [controller.tasks sortedArrayUsingDescriptors:@[
			[NSSortDescriptor sortDescriptorWithKey:@"self.lastUse" ascending:NO],
			[NSSortDescriptor sortDescriptorWithKey:@"self.name" ascending:YES]
		]];
        
        const NSUInteger maxTasks = 55;
        if (tasks.count > maxTasks)
        {
            tasks = [tasks subarrayWithRange:NSMakeRange(0, maxTasks)];
        }
        self.tasks = tasks;
        
		
		NSMenu * menu = self.menu;
		
		
		self.taskMenuItems = [self addItems:tasks toMenu:menu action:@selector(selectTask:) overflow:@"Older Tasks" titleKey:@"name"
			update:^(TTTask * inTask, NSMenuItem * inMenuItem)
			{
				if ([currentTaskID isEqualTo:inTask.identifier])
				{
					weakSelf.currentTaskMenuItem = inMenuItem;
					inMenuItem.state = NSOnState;
				}
			}
		];
		
		[self.menu addItemWithTitle:@"Add Task..." action:@selector(addTask:) keyEquivalent:@""];
		[self.menu addItem:[NSMenuItem separatorItem]];
	}
	else
	{
		self.tasks = nil;
		self.taskMenuItems = nil;
	}
	
	[self updateTime];
	
	[self.menu addItemWithTitle:@"Today's Log" action:nil keyEquivalent:@""];
	[self.menu addItemWithTitle:@"Export JSON" action:nil keyEquivalent:@""].submenu = self.scriptsMenu;
	self.summaryItem = [self.menu addItemWithTitle:@"Copy Summary" action:@selector(copyTodaysLog:) keyEquivalent:@"c"];
	[self.menu addItem:[NSMenuItem separatorItem]];
	[self.menu addItemWithTitle:@"Monthly Total" action:nil keyEquivalent:@""];
	self.monthlySummaryItem = [self.menu addItemWithTitle:@"Copy..." action:@selector(copyMonthlySummary:) keyEquivalent:@""];
	[self.menu addItem:[NSMenuItem separatorItem]];
	
	if (currentProjectID)
	{
		self.stopTrackingItem = [self.menu addItemWithTitle:@"Stop Tracking" action:@selector(stopTracking:) keyEquivalent:@""];
	}
    else
    {
        self.stopTrackingItem = nil;
    }
	
	[self.menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
	
	
	// Update main menu title
	
	if (currentProjectID)
	{
		if (currentTaskID)
		{
			self.statusItem.title = currentEvent.taskName;
		}
		else
		{
			self.statusItem.title = currentEvent.projectName;
		}
	}
	else
	{
		self.statusItem.title = @"";
	}
}

- (void)updateTime
{
    TTController * controller = [TTController controller];
    TTEvent * currentEvent = controller.currentEvent;
    
	if (self.currentProjectMenuItem && currentEvent.projectID)
	{
        TTEvent * currentProjectEvent = controller.currentProjectEvent;
		self.currentProjectMenuItem.attributedTitle = [AppDelegate attributedTitle:currentEvent.projectName time:-[currentProjectEvent.time timeIntervalSinceNow]];
	}
	
	if (self.currentTaskMenuItem && currentEvent.taskID)
	{
		self.currentTaskMenuItem.attributedTitle = [AppDelegate attributedTitle:currentEvent.taskName time:-[currentEvent.time timeIntervalSinceNow]];
	}
}

- (void)updateMenuItemSuffixes
{
	for (NSMenuItem * menuItem in self.projectMenuItems)
	{
		[self updateMenuItemSuffix:menuItem];
	}
	for (NSMenuItem * menuItem in self.taskMenuItems)
	{
		[self updateMenuItemSuffix:menuItem];
	}
	[self updateMenuItemSuffix:self.summaryItem];
	[self updateMenuItemSuffix:self.stopTrackingItem];
}

- (void)updateMenuItemSuffix:(NSMenuItem *)inMenuItem
{
	NSString * suffix = @"...";
	
	if (inMenuItem != self.currentProjectMenuItem && inMenuItem != self.currentTaskMenuItem)
	{
		NSString * title = inMenuItem.title;
		if (_optionKeyDown)
		{
			if (![title hasSuffix:suffix])
			{
				inMenuItem.title = [title stringByAppendingString:suffix];
			}
		}
		else
		{
			if ([title hasSuffix:suffix])
			{
				inMenuItem.title = [title substringToIndex:title.length - suffix.length];
			}
		}
	}
}

- (void)menuNeedsUpdate:(NSMenu *)menu
{
	[self updateTime];
}


- (void)updateOptionKey:(NSTimer *)inTimer
{
	if ([NSEvent modifierFlags] & NSAlternateKeyMask)
	{
		self.optionKeyDown = YES;
	}
	else
	{
		self.optionKeyDown = NO;
	}
}

- (void)menuWillOpen:(NSMenu *)menu
{
	self.optionKeyTimer = [NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(updateOptionKey:) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:self.optionKeyTimer forMode:NSEventTrackingRunLoopMode];
}

- (void)menuDidClose:(NSMenu *)menu
{
	[self.optionKeyTimer invalidate];
	self.optionKeyTimer = nil;
}

- (void)setOptionKeyDown:(BOOL)inKeyIsDown
{
	if (inKeyIsDown != _optionKeyDown)
	{
		_optionKeyDown = inKeyIsDown;
		
		[self updateMenuItemSuffixes];
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
		if (self.optionKeyDown)
		{
			__weak typeof(self) weakSelf = self;
			NSString * message = [NSString stringWithFormat:@"Enter the time you started working on %@", project.name];
			[self showTimestampInputAlert:message defaultTime:[NSDate date] confirmButton:@"OK"
				completion:^(NSDate *inTimestamp)
				{
					if (inTimestamp)
					{
						[weakSelf selectProject:project time:inTimestamp];
					}
					else
					{
						NSBeep();
					}
				}
			];
		}
		else
		{
			[self selectProject:project time:[NSDate date]];
		}
	}
}

- (void)selectProject:(TTProject *)inProject time:(NSDate *)inTimestamp
{
	TTController * controller = [TTController controller];
	inProject.lastUse = inTimestamp;
	[controller saveProject:inProject];
	
	[self selectProject:inProject.identifier task:nil time:inTimestamp];
}

- (void)addProject:(NSMenuItem *)inSender
{
	__weak typeof(self) weakSelf = self;
	
	[self showInputAlert:@"Add Project" defaultText:@"" confirmButton:@"Add"
		completion:^(NSString *inInputText)
		{
			if (inInputText)
			{
				if ([[TTController controller] addProjectWithName:inInputText])
				{
					[weakSelf reloadMenuDelayed];
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
	
	[self showInputAlert:@"Add Task" defaultText:@"" confirmButton:@"Add"
		completion:^(NSString *inInputText)
		{
			[[TTController controller] addTaskWithName:inInputText];
			[weakSelf reloadMenuDelayed];
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
		if (self.optionKeyDown)
		{
			__weak typeof(self) weakSelf = self;
			NSString * message = [NSString stringWithFormat:@"Enter the time you started working on %@", task.name];
			[self showTimestampInputAlert:message defaultTime:[NSDate date] confirmButton:@"OK"
				completion:^(NSDate *inTimestamp)
				{
					if (inTimestamp)
					{
						[weakSelf selectTask:task time:inTimestamp];
					}
					else
					{
						NSBeep();
					}
				}
			];
		}
		else
		{
			[self selectTask:task time:[NSDate date]];
		}
	}
}

- (void)selectTask:(TTTask *)inTask time:(NSDate *)inTimestamp
{
	TTController * controller = [TTController controller];
    inTask.lastUse = inTimestamp;
	[controller saveTask:inTask];
    
    [self selectProject:inTask.project task:inTask.identifier time:inTimestamp];
}

- (NSString *)eventSummary:(TTEvent *)inEvent
{
    NSDate * timestamp = inEvent.time;
    if (timestamp == nil)
    {
        return nil;
    }
    
    NSString * result = [[self.class dateFormatter] stringFromDate:timestamp];
    NSString * projectName = inEvent.projectName;
    if (projectName)
    {
        result = [result stringByAppendingFormat:@": %@", projectName];
        
        NSString * taskName = inEvent.taskName;
        if (taskName)
        {
            result = [result stringByAppendingFormat:@" - %@", taskName];
        }
    }
    else
    {
        result = [result stringByAppendingString:@": -"];
    }
    
    return result;
}

- (void)selectProject:(NSString *)inProjectID task:(NSString *)inTaskID time:(NSDate *)inTimestamp
{
    TTController * controller = [TTController controller];
    
    BOOL truncate = NO;
    
    NSArray< TTEvent * > * existingEvents = [controller getEventsFrom:inTimestamp to:nil];
    NSUInteger existingCount = existingEvents.count;
    if (existingCount > 0)
    {
        NSString * message = nil;
        if (existingCount == 1)
        {
            message = @"There's already an event with a later timestamp.";
            
            NSString * summary = [self eventSummary:existingEvents.firstObject];
            if (summary)
            {
                message = [message stringByAppendingFormat:@"\n\n%@", summary];
            }
            
            message = [message stringByAppendingString:@"\n\nDo you want to keep it (new event will be inserted) or start over?"];
        }
        else
        {
            message = [NSString stringWithFormat:@"There are already %@ events with a later timestamp.\n", @(existingCount)];
            
            const NSUInteger maxEvents = 10;
            const NSUInteger cutoff = maxEvents/2;
            
            for (NSUInteger i = 0; i < existingCount; ++i)
            {
                NSString * eventSummary = [self eventSummary:existingEvents[i]];
                if (eventSummary)
                {
                    message = [message stringByAppendingFormat:@"\n%@", eventSummary];
                }
                
                if (existingCount > maxEvents && i == cutoff - 1)
                {
                    message = [message stringByAppendingString:@"\n..."];
                    i = existingCount - cutoff - 1;
                }
            }
            
            message = [message stringByAppendingString:@"\n\nDo you want to keep them (new event will be inserted) or start over?"];
        }
        
        NSAlert * alert = [NSAlert alertWithMessageText:@"Existing Events" defaultButton:@"Keep" alternateButton:@"Cancel" otherButton:@"Start Over" informativeTextWithFormat:@"%@", message];
        
        NSInteger button = [alert runModal];
        switch (button)
        {
            case NSAlertDefaultReturn:
            {
                truncate = NO;
                break;
            }
            case NSAlertOtherReturn:
            {
                truncate = YES;
                break;
            }
            case NSAlertAlternateReturn:
            default:
            {
                return; // Cancel
            }
        }
    }
    
    [self selectProject:inProjectID task:inTaskID time:inTimestamp truncate:truncate];
}

- (void)selectProject:(NSString *)inProjectID task:(NSString *)inTaskID time:(NSDate *)inTimestamp truncate:(BOOL)inTruncate
{
    [[TTController controller] setCurrentProject:inProjectID task:inTaskID time:inTimestamp truncate:inTruncate];
	[self reloadMenuDelayed];
}

- (void)stopTracking:(NSMenuItem *)inSender
{
    if (self.optionKeyDown)
    {
        __weak typeof(self) weakSelf = self;
        NSString * message = @"Enter the time you stopped working";
        [self showTimestampInputAlert:message defaultTime:[NSDate date] confirmButton:@"OK"
            completion:^(NSDate *inTimestamp)
            {
                if (inTimestamp)
                {
                    [weakSelf stopTrackingAtTimestamp:inTimestamp];
                }
                else
                {
                    NSBeep();
                }
            }
        ];
    }
    else
    {
        [self stopTrackingAtTimestamp:[NSDate date]];
    }
}

- (void)stopTrackingAtTimestamp:(NSDate *)inTimestamp
{
    [self selectProject:nil task:nil time:inTimestamp];
}

+ (NSString *)durationString:(NSTimeInterval)inTimeInterval
{
	double seconds = inTimeInterval;
	
	double hours = floor(seconds / 3600.0);
	seconds -= 3600.0*hours;
	
	double minutes = floor(seconds / 60.0);
	seconds -= 60.0*minutes;
	
	if (hours > 0.0)
	{
		return [NSString stringWithFormat:@"%.0fh %.0fm", hours, minutes + round(seconds/60.0)];
	}
	else if (minutes > 0.0)
	{
		return [NSString stringWithFormat:@"%.0fm", minutes + round(seconds/60.0)];
	}
	else
	{
		return [NSString stringWithFormat:@"%.0fs", seconds];
	}
}

- (TTLog *)getLogSummaryForDayStarting:(NSDate *)inStartTime
{
	return [self getLogSummaryFrom:inStartTime to:[inStartTime dateByAddingTimeInterval:24.0*60.0*60.0]];
}

- (TTLog *)getLogSummaryFrom:(NSDate *)inStartTime to:(NSDate *)inEndTime
{
	NSArray * events = [[TTController controller] getEventsFrom:inStartTime to:inEndTime];
	
	TTLog * log = [TTLog new];
	for (TTEvent * event in events)
	{
		[log addEvent:event];
	}
	
	return log;
}

- (NSString *)logSummaryToString:(TTLog *)inLog date:(NSDate *)inDate
{
	NSMutableString * logString = [NSMutableString new];
	
	[logString appendString:[NSDateFormatter localizedStringFromDate:inDate dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle]];
	[logString appendString:@"\n\n"];
	
	
	for (TTProjectLog * projectLog in inLog.projectLogs.allValues)
	{
		[logString appendFormat:@"%@: %@\n",
			projectLog.projectName,
			[AppDelegate durationString:projectLog.totalTime]
		];
		
		for (TTTaskLog * taskLog in projectLog.taskLogs.allValues)
		{
			[logString appendFormat:@"- %@: %@\n",
				taskLog.taskName,
				[AppDelegate durationString:taskLog.totalTime]
			];
		}
		
		[logString appendString:@"\n"];
	}
	
	return logString;
}

- (NSString *)logSummaryToJsonString:(TTLog *)inLog
{
	NSArray * projectLogDicts = [inLog toDictionaries];
	
	NSError * error = nil;
	NSData * jsonData = [NSJSONSerialization dataWithJSONObject:projectLogDicts options:NSJSONWritingPrettyPrinted error:&error];
	return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSDate *)defaultStartOfDay
{
	return [TTStartOfDay([NSDate date]) dateByAddingTimeInterval:4.0*60.0*60.0];
}

- (void)runScriptWithTodaysLog:(NSString *)inScriptPath
{
	NSDate * startOfToday = [self defaultStartOfDay];
	
	if (self.optionKeyDown)
	{
		__weak typeof(self) weakSelf = self;
		
		[self showTimestampInputAlert:@"Export JSON for log of day starting:" defaultTime:startOfToday confirmButton:@"Export"
			completion:^(NSDate *inTimestamp)
			{
				if (inTimestamp)
				{
					[weakSelf runScript:inScriptPath withLogForDayStarting:inTimestamp];
				}
			}
		];
	}
	else
	{
		[self runScript:inScriptPath withLogForDayStarting:startOfToday];
	}
}

- (void)runScript:(NSString *)inScriptPath withLogForDayStarting:(NSDate *)inStartOfDay
{
	TTLog * log = [self getLogSummaryForDayStarting:inStartOfDay];
	NSString * logString = [self logSummaryToJsonString:log];
	[self runScript:inScriptPath withInput:logString];
}

- (void)copyTodaysLog:(NSMenuItem *)inMenuItem
{
	NSDate * startOfToday = [self defaultStartOfDay];
	
	if (self.optionKeyDown)
	{
		__weak typeof(self) weakSelf = self;
		
		[self showTimestampInputAlert:@"Copy log summary for day starting:" defaultTime:startOfToday confirmButton:@"Copy Log"
			completion:^(NSDate *inTimestamp)
			{
				if (inTimestamp)
				{
					[weakSelf copyLogForDayStarting:inTimestamp];
				}
			}
		];
	}
	else
	{
		[self copyLogForDayStarting:startOfToday];
	}
}

- (void)copyLogForDayStarting:(NSDate *)inStartOfDay
{
	TTLog * log = [self getLogSummaryForDayStarting:inStartOfDay];
	NSString * logString = [self logSummaryToString:log date:inStartOfDay];
	
	NSLog(@"Log:\n%@", logString);

	[[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[[NSPasteboard generalPasteboard] setString:logString forType:NSStringPboardType];
}

- (void)copyMonthlySummary:(NSMenuItem *)inMenuItem
{
	NSDate * startOfMonth = [TTStartOfMonth([NSDate dateWithTimeIntervalSinceNow:-30.0*24.0*60.0*60.0]) dateByAddingTimeInterval:4.0*60.0*60.0];
	
	__weak typeof(self) weakSelf = self;
		
	[self showTimestampInputAlert:@"Copy summary for month starting:" defaultTime:startOfMonth confirmButton:@"Copy Log"
		completion:^(NSDate *inTimestamp)
		{
			if (inTimestamp)
			{
				[weakSelf copyLogForMonthStarting:inTimestamp];
			}
		}
	];
}

- (void)copyLogForMonthStarting:(NSDate *)inDate
{
	NSCalendar * calendar = [NSCalendar currentCalendar];
	
	NSDate * endDate = [calendar dateByAddingUnit:NSMonthCalendarUnit value:1 toDate:inDate options:0];
	
	TTLog * log = [self getLogSummaryFrom:inDate to:endDate];
	NSMutableString * logString = [self monthlyLogSummary:log date:inDate];
	[logString appendString:@"\n\n"];
	
	NSDate * day = inDate;
	
	while ([day compare:endDate] == NSOrderedAscending)
	{
		TTLog * dayLog = [self getLogSummaryForDayStarting:day];
		if (dayLog.projectLogs.count > 0)
		{
			NSString * dayLogString = [self logSummaryToString:dayLog date:day];
			
			[logString appendString:dayLogString];
			
			[logString appendString:@"\n"];
		}
		
		day = [calendar dateByAddingUnit:NSDayCalendarUnit value:1 toDate:day options:0];
	}
	
	
	NSLog(@"Log:\n%@", logString);

	[[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[[NSPasteboard generalPasteboard] setString:logString forType:NSStringPboardType];
}


- (NSMutableString *)monthlyLogSummary:(TTLog *)inLog date:(NSDate *)inDate
{
	NSMutableString * logString = [NSMutableString new];
	
	[logString appendString:@"Month starting "];
	[logString appendString:[NSDateFormatter localizedStringFromDate:inDate dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterNoStyle]];
	[logString appendString:@"\n"];
	
	
	for (TTProjectLog * projectLog in inLog.projectLogs.allValues)
	{
		double projectWorkDays = projectLog.totalTime/(8.0*3600.0);
		
		[logString appendFormat:@"- %@: %.2f d\n",
			projectLog.projectName,
			projectWorkDays
		];
	}
	
	return logString;
}

- (NSString *)runScript:(NSString *)inScriptPath withInput:(NSString *)inInput
{
	NSTask *task = [[NSTask alloc] init];
	task.launchPath = @"/bin/sh";
	task.arguments = @[ inScriptPath ];

	NSPipe *readPipe = [NSPipe pipe];
	NSFileHandle *readHandle = [readPipe fileHandleForReading];

	NSPipe *writePipe = [NSPipe pipe];
	NSFileHandle *writeHandle = [writePipe fileHandleForWriting];

	[task setStandardInput: writePipe];
	[task setStandardOutput: readPipe];

	[task launch];

	[writeHandle writeData: [inInput dataUsingEncoding: NSUTF8StringEncoding]];
	[writeHandle closeFile];

	NSData * output = [readHandle readDataToEndOfFile];
	return [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
}

- (void)showInputAlert:(NSString *)inMessage defaultText:(NSString *)inDefaultText confirmButton:(NSString *)inConfirmButton completion:(void (^)(NSString * inInputText))inCompletionBlock
{
	NSAlert * alert = [NSAlert alertWithMessageText:inMessage defaultButton:inConfirmButton alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@""];
	
	NSTextField * textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300.0, 24.0)];
	textField.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	textField.stringValue = inDefaultText;
	alert.accessoryView = textField;
	
	NSString * resultText = nil;
	
	[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	
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

+ (NSDateFormatter *)dateFormatter
{
	static NSDateFormatter * sDateFormatter = nil;
	static dispatch_once_t sOnceToken = 0;
	dispatch_once(&sOnceToken, ^{
		sDateFormatter = [NSDateFormatter new];
		[sDateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
	});
	return sDateFormatter;
}

- (void)showTimestampInputAlert:(NSString *)inMessage defaultTime:(NSDate *)inDefaultTime confirmButton:(NSString *)inConfirmButton completion:(void (^)(NSDate * inTimestamp))inCompletionBlock
{
	NSDateFormatter * dateFormatter = [self.class dateFormatter];
	
	NSString * defaultTimeString = [dateFormatter stringFromDate:inDefaultTime ?: [NSDate date]];
	
	[self showInputAlert:inMessage defaultText:defaultTimeString confirmButton:@"OK"
		completion:^(NSString * inInputText)
		{
			NSDate * timestamp = nil;
			if (inInputText)
			{
				timestamp = [dateFormatter dateFromString:inInputText];
				if (! timestamp)
				{
					NSLog(@"Could not parse %@", inInputText);
				}
			}
			inCompletionBlock(timestamp);
		}
	];
}

@end // AppDelegate
