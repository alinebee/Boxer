//
//  BXTemplateImageView.m
//  Boxer
//
//  Created by Alun Bestor on 17/06/2011.
//  Copyright 2011 Alun Bestor and contributors. All rights reserved.
//

#import "BXTemplateImageCell.h"


@implementation BXTemplateImageCell
@synthesize imageColor, imageShadow;

- (void) dealloc
{
	[self setImageColor: nil], [imageColor release];
	[self setImageShadow: nil], [imageShadow release];
	
	[super dealloc];
}

- (void) drawInteriorWithFrame: (NSRect)cellFrame inView: (NSView *)controlView
{	
	//Apply our foreground colour and shadow when drawing any template image
	if ([[self image] isTemplate])
	{
		NSImage *templateImage = [[self image] copy];
		
		NSRect imageFrame = NSMakeRect(0, 0, cellFrame.size.width, cellFrame.size.height);
		
		//First resize the image to the intended size and fill it with the foreground colour
		[templateImage setSize: imageFrame.size];
		[templateImage lockFocus];
			[[self imageColor] set];
			NSRectFillUsingOperation(imageFrame, NSCompositeSourceAtop);
		[templateImage unlockFocus];
		
		//Then render the matted image into the final context along with the drop shadow
		[NSGraphicsContext saveGraphicsState];
			[[self imageShadow] set];
			[templateImage drawInRect: cellFrame fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0f];
		[NSGraphicsContext restoreGraphicsState];
		[templateImage release];
	}
	else
	{
		[super drawInteriorWithFrame: cellFrame inView: controlView];
	}
}

@end

@implementation BXHUDImageCell

- (void) awakeFromNib
{
	if (![self imageColor])
	{
		[self setImageColor: [NSColor whiteColor]];
	}
	
	if (![self imageShadow])
	{
		NSShadow *theShadow = [[NSShadow alloc] init];
		
		[theShadow setShadowBlurRadius: 8.0f];
		[theShadow setShadowOffset: NSMakeSize(0.0f, -2.0f)];
		
		[self setImageShadow: theShadow];
		[theShadow release];
	}
}

@end