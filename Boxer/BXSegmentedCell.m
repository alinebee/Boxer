/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSegmentedCell.h"

//Most of this is copypasta from BGHUDSegmentedCell, because of its monolithic draw functions.

@interface NSSegmentedCell (private)
-(NSRect)rectForSegment: (NSInteger)segment inFrame: (NSRect)frame;
@end

@implementation BXSegmentedCell

- (void) drawWithFrame: (NSRect)frame inView: (NSView *)view
{
	NSBezierPath *border;
	
	switch ([self segmentStyle]) {
		default: // Silence uninitialized variable warnings
		case NSSegmentStyleSmallSquare:
			
			//Adjust frame for shadow
			frame.origin.x += 1.5f;
			frame.origin.y += .5f;
			frame.size.width -= 3;
			frame.size.height -= 3;
			
			border = [[NSBezierPath alloc] init];
			[border appendBezierPathWithRect: frame];
			
			break;
			
		case NSSegmentStyleRounded: //NSSegmentStyleTexturedRounded:
			
			//Adjust frame for shadow
			frame.origin.x += 1.5f;
			frame.origin.y += .5f;
			frame.size.width -= 3;
			frame.size.height -= 3;
			
			border = [[NSBezierPath alloc] init];
			
			CGFloat cornerRadius = frame.size.height / 2;
			[border appendBezierPathWithRoundedRect: frame
											xRadius: cornerRadius yRadius: cornerRadius];
			break;
	}
	
	//Setup to Draw Border
	[NSGraphicsContext saveGraphicsState];
	
	//Set Shadow + Border Color
	[[[[BGThemeManager keyedManager] themeForKey: self.themeKey] dropShadow] set];
	[[[[BGThemeManager keyedManager] themeForKey: self.themeKey] strokeColor] set];
	
	//Draw Border + Shadow
	[border stroke];
	
	[NSGraphicsContext restoreGraphicsState];
	
	[border release];
	
	int segCount = 0;
	
	while (segCount <= [self segmentCount] -1) {
		
		[self drawSegment: segCount inFrame: frame withView: view];
		segCount++;
	}
}

- (void) drawSegment: (NSInteger)segment inFrame: (NSRect)frame withView: (NSView *)view
{
	//Calculate rect for this segment
	//rectForSegment will return too wide a value for the final segment for some reason,
	//so we have to crop it to the actual view frame
	NSRect fillRect = NSIntersectionRect([self rectForSegment: segment inFrame: frame], frame);
	NSBezierPath *fillPath;
	
	switch ([self segmentStyle]) {
		default: // Silence uninitialized variable warnings
		case NSSegmentStyleSmallSquare:
			fillPath = [[NSBezierPath alloc] init];
			[fillPath appendBezierPathWithRect: fillRect];
			
			break;
			
		case NSSegmentStyleRounded: //NSSegmentStyleTexturedRounded:
			fillPath = [[NSBezierPath alloc] init];
			
			CGFloat cornerRadius = fillRect.size.height / 2;
			
			//If this is the first segment, draw rounded corners
			if(segment == 0) {
				[fillPath appendBezierPathWithRoundedRect: fillRect xRadius: cornerRadius yRadius: cornerRadius];
				
				//Setup our joining rect
				NSRect joinRect = fillRect;
				joinRect.origin.x += cornerRadius;
				joinRect.size.width -= cornerRadius;
				
				[fillPath appendBezierPathWithRect: joinRect];
				
				//If this is the last segment, draw rounded corners
			} else if (segment == ([self segmentCount] -1)) {
				[fillPath appendBezierPathWithRoundedRect: fillRect xRadius: cornerRadius yRadius: cornerRadius];
				
				//Setup our joining rect
				NSRect joinRect = fillRect;
				joinRect.size.width -= cornerRadius;
				
				[fillPath appendBezierPathWithRect: joinRect];
				
			} else {
				NSAssert(segment != 0 && segment != ([self segmentCount] -1), @"should be a middle segment");
				[fillPath appendBezierPathWithRect: fillRect];
			}
			
			break;
	}
	
	BOOL isSelected;
	
	//In momentary tracking, we should only look at the currently-reported selected segment...
	if ([self trackingMode] == NSSegmentSwitchTrackingMomentary) isSelected = ([self selectedSegment] == segment);
	//...for other tracking modes, check if the segment is reported as selected.
	else isSelected = [self isSelectedForSegment: segment];
	
	//Fill our paths
	if (isSelected) {
		
		[[[[BGThemeManager keyedManager] themeForKey: self.themeKey] highlightGradient] drawInBezierPath: fillPath angle: 90];
	} else {
		
		[[[[BGThemeManager keyedManager] themeForKey: self.themeKey] normalGradient] drawInBezierPath: fillPath angle: 90];
	}
	
	[fillPath release];
	
	//Draw Segment dividers ONLY if they are
	//inside segments
	if(segment != ([self segmentCount] -1)) {
		
		[[[[BGThemeManager keyedManager] themeForKey: self.themeKey] strokeColor] set];
		[NSBezierPath strokeLineFromPoint: NSMakePoint(fillRect.origin.x + fillRect.size.width , fillRect.origin.y)
								  toPoint: NSMakePoint(fillRect.origin.x + fillRect.size.width, fillRect.origin.y + fillRect.size.height)];
	}
	
	[self drawInteriorForSegment: segment withFrame: fillRect];
}

-(void) drawInteriorForSegment: (NSInteger)segment withFrame: (NSRect)rect
{	
	BOOL isSelected;
	
	//In momentary tracking, we should only look at the currently-reported selected segment...
	if ([self trackingMode] == NSSegmentSwitchTrackingMomentary) isSelected = ([self selectedSegment] == segment);
	//...for other tracking modes, check if the segment is reported as selected.
	else isSelected = [self isSelectedForSegment: segment];
	
	NSAttributedString *newTitle;
	
	//if([self labelForSegment: segment] != nil) {
	
	NSMutableDictionary *textAttributes = [[NSMutableDictionary alloc] initWithCapacity: 0];
	
	[textAttributes setValue: [NSFont controlContentFontOfSize: [NSFont systemFontSizeForControlSize: [self controlSize]]] forKey: NSFontAttributeName];
	
	//--Added 2010-06-28 by Alun Bestor to show disabled segments as properly disabled
	NSColor *textColor;
	if ([self isEnabledForSegment: segment])
	{
		textColor = [[[BGThemeManager keyedManager] themeForKey: self.themeKey] textColor];
	}
	else
	{
		textColor = [[[BGThemeManager keyedManager] themeForKey: self.themeKey] disabledTextColor];
	}
	[textAttributes setValue: textColor forKey: NSForegroundColorAttributeName];
	//--End of modifications
	
	if([self labelForSegment: segment]) {
		
		newTitle = [[NSAttributedString alloc] initWithString: [self labelForSegment: segment] attributes: textAttributes];
	} else {
		
		newTitle = [[NSAttributedString alloc] initWithString: @"" attributes: textAttributes];
	}
	
	[textAttributes release];
	//}
	
	NSRect textRect = rect;
	NSRect imageRect = rect;
	
	if([super imageForSegment: segment] != nil) {
		
		//Copy the image since we will be modifying its size and/or tinting it
		NSImage *image = [[[self imageForSegment: segment] copy] autorelease];
		
		[image setFlipped: YES];
		
		if([self imageScalingForSegment: segment] == NSImageScaleProportionallyDown) {
			
			CGFloat newHeight = roundf(rect.size.height - 7);
			CGFloat resizeRatio = newHeight / [image size].height;
			
			NSSize newSize = NSMakeSize([image size].width * resizeRatio, newHeight);
			
			[image setSize: newSize];
		}
		
		if ([image isTemplate])
		{
			NSColor *tint = [NSColor whiteColor];
			
			NSRect bounds = NSZeroRect;
			bounds.size = [image size];   
			
			[image lockFocus];
			[tint set];
			NSRectFillUsingOperation(bounds, NSCompositeSourceAtop);
			[image unlockFocus];
		}
		
		if([self labelForSegment: segment] != nil && ![[self labelForSegment: segment] isEqualToString: @""]) {
			
			imageRect.origin.y += (BGCenterY(rect) - ([image size].height /2));
			imageRect.origin.x += (BGCenterX(rect) - (([image size].width + [newTitle size].width + 5) /2));
			imageRect.size = [image size];
			
			textRect.origin.y += (BGCenterY(rect) - ([newTitle size].height /2));
			textRect.origin.x += imageRect.origin.x + [image size].width + 5;
			textRect.size = [newTitle size];
			
			[newTitle drawInRect: textRect];
			
		} else {
			
			//Draw Image Alone
			imageRect.origin.y += (BGCenterY(rect) - ([image size].height /2));
			imageRect.origin.x += (BGCenterX(rect) - ([image size].width /2));
			imageRect.size = [image size];
		}
		
		NSShadow *imageShadow = [[[BGThemeManager keyedManager] themeForKey: self.themeKey] dropShadow];
		
		CGFloat imageAlpha = 0.8f;
		if (isSelected) imageAlpha = 1.0f;
		if (![self isEnabledForSegment: segment]) imageAlpha = 0.33f;
		
		BOOL useShadow = ([image isTemplate] && [self isEnabledForSegment: segment] && !isSelected);
		
		[NSGraphicsContext saveGraphicsState];
		if (useShadow) [imageShadow set];
		
		[image drawInRect: imageRect
				 fromRect: NSZeroRect 
				operation: NSCompositeSourceAtop
				 fraction: imageAlpha];
		[NSGraphicsContext restoreGraphicsState];
	} else {
		
		textRect.origin.y += (BGCenterY(rect) - ([newTitle size].height /2));
		textRect.origin.x += (BGCenterX(rect) - ([newTitle size].width /2));
		textRect.size = [newTitle size];
		
		if(textRect.origin.x < 3) { textRect.origin.x = 3; }
		
		[newTitle drawInRect: textRect];
	}
	
	[newTitle release];
}

@end
