//
//  BGHUDStepperCell.m
//  BGHUDAppKit
//
//  Created by BinaryGod on 4/6/09.
//  Copyright 2009 none. All rights reserved.
//

#import "BGHUDStepperCell.h"


@implementation BGHUDStepperCell

@synthesize themeKey;

-(void)drawWithFrame:(NSRect) frame inView:(NSView *) controlView {
	
	/*NSLog(@"Reserved: %i", _stFlags.reserved);
	
	[super drawWithFrame: frame inView: controlView];*/
	
	frame = NSInsetRect(frame, 2, 2);
	[[NSColor redColor] set];
	NSFrameRect(frame);
}

-(void)rightMouseDown:(NSEvent *) theEvent {

	NSLog(@"RIGHT");
}

-(void)mouseDown:(NSEvent *) theEvent {
	NSLog(@"TEST!!!!");
	/*NSRect rect = [[self controlView] bounds];
	
	NSPoint mousePoint = [[self controlView] convertPoint: [NSEvent mouseLocation] fromView: self];
	
	NSLog(@"Point: %@", NSStringFromPoint(mousePoint));*/
}

@end
