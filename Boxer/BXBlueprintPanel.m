/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXBlueprintPanel.h"
#import "NSView+BXDrawing.h"
#import "NSBezierPath+MCAdditions.h"
#import "BXGeometry.h"

@implementation BXBlueprintPanel

- (NSPoint) _phaseForPattern: (NSImage *)pattern
{
	NSPoint offset = [self offsetFromWindowOrigin];
	NSRect panelFrame = [self frame];
	return NSMakePoint(offset.x + ((panelFrame.size.width - [pattern size].width) / 2),
					   offset.y);
}

- (void) _drawBlueprintInRect: (NSRect)dirtyRect
{
	NSColor *blueprintColor = [NSColor colorWithPatternImage: [NSImage imageNamed: @"Blueprint.jpg"]];
	NSPoint patternPhase	= [self _phaseForPattern: [blueprintColor patternImage]];
	
	[NSGraphicsContext saveGraphicsState];
		[[NSGraphicsContext currentContext] setPatternPhase: patternPhase];
		[blueprintColor set];
		[NSBezierPath fillRect: [self bounds]];
	[NSGraphicsContext restoreGraphicsState];
}

- (void) _drawLightingInRect: (NSRect)dirtyRect
{
	NSGradient *lighting = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.2f]
														 endingColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.4f]];

	NSRect backgroundRect = [self bounds];
	NSPoint startPoint	= NSMakePoint(NSMidX(backgroundRect), NSMaxY(backgroundRect));
	NSPoint endPoint	= NSMakePoint(NSMidX(backgroundRect), NSMidY(backgroundRect));
	CGFloat startRadius = NSWidth(backgroundRect) * 0.1f;
	CGFloat endRadius	= NSWidth(backgroundRect) * 0.75f;
	
	[lighting drawFromCenter: startPoint radius: startRadius
					toCenter: endPoint radius: endRadius
					 options: NSGradientDrawsBeforeStartingLocation | NSGradientDrawsAfterEndingLocation];
	
	[lighting release];
}

- (void) _drawShadowInRect: (NSRect)dirtyRect
{
	//Draw a soft shadow beneath the titlebar
	NSRect shadowRect = [self bounds];
	shadowRect.origin.y += shadowRect.size.height - 6.0f;
	shadowRect.size.height = 6.0f;
	
	//Draw a 1-pixel groove at the bottom of the view
	NSRect grooveRect = [self bounds];
	grooveRect.size.height = 1.0f;
	
	if (NSIntersectsRect(dirtyRect, shadowRect))
	{
		NSGradient *topShadow = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.2f]
															  endingColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.0f]];
		
		[topShadow drawInRect: shadowRect angle: 270.0f];
		[topShadow release];
	}
	
	if (NSIntersectsRect(dirtyRect, grooveRect))
	{
		NSColor *grooveColor = [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.33f];
		[NSGraphicsContext saveGraphicsState];
			[grooveColor set];
			[NSBezierPath fillRect: grooveRect];
		[NSGraphicsContext restoreGraphicsState];
	}
}

- (void) drawRect: (NSRect)dirtyRect
{
	[NSBezierPath clipRect: dirtyRect];
	
	//First, fill the background with our pattern
	[self _drawBlueprintInRect: dirtyRect];

	//Then, draw the lighting onto the background
	[self _drawLightingInRect: dirtyRect];
	
	//Finally, draw the top and bottom shadows
	[self _drawShadowInRect: dirtyRect];
}

@end


@implementation BXBlueprintTextFieldCell

- (BOOL) isOpaque
{
	return NO;
}

- (BOOL) drawsBackground
{
	return NO;
}

- (void) drawWithFrame: (NSRect)frame inView: (NSView *)controlView
{
	BOOL isFocused = [self showsFirstResponder] && [[controlView window] isKeyWindow];
	CGFloat backgroundOpacity = (isFocused) ? 0.4f : 0.2f;
	
	NSColor *textColor = [NSColor whiteColor];
	NSColor *backgroundColor = [NSColor colorWithCalibratedWhite: 0.0f alpha: backgroundOpacity];
	
	NSRect visibleFrame = frame;
	visibleFrame.size.height -= 2.0f;
	visibleFrame.origin.y += 2.0f;
	
	//We draw ourselves with rounded corners, and a custom background and inner shadow
	CGFloat cornerRadius = 3.0f; //NSHeight(frame) / 2.0f;
	NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect: visibleFrame
															   xRadius: cornerRadius
															   yRadius: cornerRadius];
	
	
	NSShadow *innerShadow = [[NSShadow alloc] init];
	[innerShadow setShadowColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.66f]];
	[innerShadow setShadowBlurRadius: 2.0f];
	[innerShadow setShadowOffset: NSMakeSize(0.0f, -1.0f)];
	
	[NSGraphicsContext saveGraphicsState];
		[backgroundColor set];
		if (isFocused) NSSetFocusRingStyle(NSFocusRingBelow);
		[background fill];
		[background fillWithInnerShadow: innerShadow];
	[NSGraphicsContext restoreGraphicsState];
	
	
	NSTextView* textView = (NSTextView *)[[controlView window] fieldEditor: NO forObject: controlView];
	
	[self setTextColor: textColor];
	[textView setInsertionPointColor: textColor];
	
	[self drawInteriorWithFrame: frame inView: controlView];
	
	[innerShadow release];
}

@end


@implementation BXBlueprintProgressIndicator

- (void) awakeFromNib
{
	[self setColor: [NSColor whiteColor]];
	[self setDrawsBackground: NO];
}

- (void) drawRect: (NSRect)dirtyRect
{
	NSShadow *dropShadow = [[NSShadow alloc] init];
	[dropShadow setShadowOffset: NSMakeSize(0.0f, 0.0f)];
	[dropShadow setShadowBlurRadius: 3.0f];
	[dropShadow setShadowColor: [[NSColor blackColor] colorWithAlphaComponent: 0.5f]];
	
	[NSGraphicsContext saveGraphicsState];
		[dropShadow set];
		[super drawRect: dirtyRect];
	[NSGraphicsContext restoreGraphicsState];
	[dropShadow release];
}
@end