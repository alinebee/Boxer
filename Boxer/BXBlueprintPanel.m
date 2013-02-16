/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXBlueprintPanel.h"
#import "NSView+ADBDrawingHelpers.h"
#import "NSBezierPath+MCAdditions.h"
#import "ADBGeometry.h"
#import "NSShadow+ADBShadowExtensions.h"

@implementation BXBlueprintPanel


- (void) _drawBlueprintInRect: (NSRect)dirtyRect
{
    NSImage *pattern = [NSImage imageNamed: @"Blueprint.jpg"];
	NSColor *blueprintColor = [NSColor colorWithPatternImage: pattern];
    
	NSPoint offset = [NSView focusView].offsetFromWindowOrigin;
	NSRect panelFrame = self.bounds;
	NSPoint patternPhase = NSMakePoint(offset.x + ((panelFrame.size.width - pattern.size.width) / 2),
                                       offset.y);
	
	[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext currentContext].patternPhase = patternPhase;
		[blueprintColor set];
		[NSBezierPath fillRect: dirtyRect];
	[NSGraphicsContext restoreGraphicsState];
}

- (void) _drawLightingInRect: (NSRect)dirtyRect
{
	NSGradient *lighting = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.2f]
														 endingColor: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.4f]];

	NSRect backgroundRect = self.bounds;
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
	NSRect shadowRect = self.bounds;
	shadowRect.origin.y += shadowRect.size.height - 6.0f;
	shadowRect.size.height = 6.0f;
	
	//Draw a 1-pixel groove at the bottom of the view
	NSRect grooveRect = self.bounds;
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
	BOOL isFocused = self.showsFirstResponder && controlView.window.isKeyWindow;
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
	
	
	NSShadow *innerShadow = [NSShadow shadowWithBlurRadius: 2.0f
                                                    offset: NSMakeSize(0.0f, -1.0f)
                                                     color: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.66f]];
    
	[NSGraphicsContext saveGraphicsState];
		[backgroundColor set];
		if (isFocused)
            NSSetFocusRingStyle(NSFocusRingBelow);
		[background fill];
		[background fillWithInnerShadow: innerShadow];
	[NSGraphicsContext restoreGraphicsState];
	
	
	NSTextView* textView = (NSTextView *)[controlView.window fieldEditor: NO forObject: controlView];
	
    self.textColor = textColor;
    textView.insertionPointColor = textColor;
    
	[self drawInteriorWithFrame: frame inView: controlView];
}

@end


@implementation BXBlueprintProgressIndicator

- (void) awakeFromNib
{
    [super awakeFromNib];
	self.dropShadow = [NSShadow shadowWithBlurRadius: 3.0f
                                              offset: NSMakeSize(0.0f, 0.0f)
                                               color: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.5f]];
}
@end