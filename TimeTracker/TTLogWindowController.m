//
//  TTLogWindowController.m
//  TimeTracker
//
//  Created by Lieven Dekeyser on 31/03/15.
//  Copyright (c) 2015 Plane Tree Software. All rights reserved.
//

#import "TTLogWindowController.h"


@interface TTLogWindowController ()
@property (nonatomic, strong) IBOutlet NSTableView * tableView;
@end // TTLogWindowController ()


@implementation TTLogWindowController

- (instancetype)init
{
	if ((self = [super initWithWindowNibName:@"TTLogWindowController"]))
	{
	}
	return self;
}

- (void)windowWillLoad
{
	[super windowWillLoad];
	
	self.window.title = @"Testing";
}

@end
