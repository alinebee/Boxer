/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFilterGallery.h"
#import "NSView+BXDrawing.h"
#import <QuartzCore/QuartzCore.h>

@implementation BXFilterGallery
- (void) drawRect: (NSRect)dirtyRect
{
	NSImage *wallpaper	= [NSImage imageNamed: @"GalleryBkg.jpg"];
	NSColor *pattern	= [NSColor colorWithPatternImage: wallpaper];
	
	NSSize patternSize	= [wallpaper size];
	NSSize viewSize		= [self bounds].size;
	NSPoint patternOffset	= [self offsetFromWindowOrigin];
	
	NSPoint patternPhase = NSMakePoint(
		//Center the pattern horizontally
		patternOffset.x + ((viewSize.width - patternSize.width) / 2),
		//Lock the pattern to the bottom of the view
		patternOffset.y + 1.0f
	);

	//Also add a bevel line at the bottom of the view
	NSColor *bevelColor = [NSColor whiteColor];
	NSRect bevelRect = [self bounds];
	bevelRect.size.height = 1.0f;
	
	//Fill the view with the background pattern and draw the bevel
	[NSGraphicsContext saveGraphicsState];
		[pattern set];
		[[NSGraphicsContext currentContext] setPatternPhase: patternPhase];
		[NSBezierPath fillRect: dirtyRect];
	
		//Don't bother drawing the bevel if it's not dirty
		if (NSIntersectsRect(dirtyRect, bevelRect))
		{
			[bevelColor set];
			[NSBezierPath fillRect: bevelRect];
		}
	[NSGraphicsContext restoreGraphicsState];	
}
@end

@implementation BXFilterPortrait
@synthesize illumination;

+ (id)defaultAnimationForKey: (NSString *)key
{
    if ([key isEqualToString: @"illumination"])
		return [CABasicAnimation animation];

    return [super defaultAnimationForKey:key];
}

- (void) setState: (NSInteger)value
{
	[super setState: value];
	if (value)	[[self animator] setIllumination: 1.0f];
	else		[[self animator] setIllumination: 0.0f];
}

- (void) setIllumination: (CGFloat)newValue
{
	illumination = newValue;
	[self setNeedsDisplay: YES];
}
@end

@implementation BXFilterPortraitCell

- (void) awakeFromNib
{
	//Prevent the portrait from darkening when pressed in.
	[self setHighlightsBy: NSNoCellMask];
}

- (void) _drawSpotlightWithFrame: (NSRect)frame inView: (NSView *)controlView withAlpha: (CGFloat)alpha
{
	NSImage *spotlight = [NSImage imageNamed: @"GallerySpotlight"];
	
	[spotlight setFlipped: [controlView isFlipped]];
	
	[spotlight drawInRect: frame
				 fromRect: NSZeroRect
				operation: NSCompositePlusLighter
				 fraction: alpha];
}

- (NSFont *) _labelFont
{
	//Render the text in bold if this button is selected or the user is pressing the button
	if ([self state] || [self isHighlighted])
		return [NSFont boldSystemFontOfSize: 0];
	else
		return [NSFont systemFontOfSize: 0];
}

- (NSColor *) _textColor
{
	//Render the text in white if this button is selected
	return ([self state]) ? [NSColor whiteColor] : [NSColor lightGrayColor];
}

- (CGFloat) _shadeLevel
{
	return 0.25f;
}

- (NSAttributedString *) attributedTitle
{
	NSFont *font = [self _labelFont];
	NSColor *textColor = [self _textColor];
	
	NSShadow *textShadow = [[NSShadow new] autorelease];	
	[textShadow setShadowOffset: NSMakeSize(0.0f, -1.0f)];
	[textShadow setShadowBlurRadius: 2.0f];
	[textShadow setShadowColor: [NSColor blackColor]];
	
	NSMutableAttributedString *title = [[super attributedTitle] mutableCopy];
	NSRange textRange = NSMakeRange(0, [title length]);
	
	[title addAttribute: NSFontAttributeName value: font range: textRange];
	[title addAttribute: NSForegroundColorAttributeName value: textColor range: textRange];
	[title addAttribute: NSShadowAttributeName value: textShadow range: textRange];
	
	return [title autorelease];
}

- (NSRect) titleRectForBounds: (NSRect)theRect
{
	//Position the title to occupy the bottom quarter of the button.
	theRect.origin.y = 72.0f;
	return theRect;
}

- (void) drawWithFrame: (NSRect)frame inView: (BXFilterPortrait *)controlView
{
	if ([controlView illumination] > 0.0f)
	{
		[self _drawSpotlightWithFrame: frame inView: controlView withAlpha: [controlView illumination]];
	}
	[super drawWithFrame: frame inView: controlView];
}

- (void) drawImage: (NSImage *)image	
		 withFrame: (NSRect)frame 
			inView: (BXFilterPortrait *)controlView
{
	if ([controlView illumination] < 0.9)
	{
		CGFloat shadeLevel = (1.0f - [controlView illumination]) * [self _shadeLevel];
		NSColor *shade = [NSColor colorWithCalibratedWhite: 0.0f alpha: shadeLevel];
		
		image = [[image copy] autorelease];
		NSRect bounds;
		bounds.origin = NSZeroPoint;
		bounds.size = [image size];
		[image lockFocus];
			[shade set];
			NSRectFillUsingOperation(bounds, NSCompositeSourceAtop);
		[image unlockFocus];
	}
	[super drawImage: image withFrame: frame inView: controlView];
}

@end
