/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFilterGallery.h"
#import <QuartzCore/QuartzCore.h>

@implementation BXFilterGallery
- (void) drawRect: (NSRect)dirtyRect
{
	NSImage *wallpaper	= [NSImage imageNamed: @"GalleryBkg.jpg"];
	NSColor *pattern	= [NSColor colorWithPatternImage: wallpaper];
	
	NSSize patternSize	= [wallpaper size];
	NSRect frame		= [self frame];
	
	NSPoint patternPhase = NSMakePoint(
		//Center the pattern horizontally
		((frame.size.width - patternSize.width) / 2) + frame.origin.x,
		//Lock the pattern to the bottom of the view
		frame.origin.y + 1.0
	);

	//Also add a bevel line at the bottom of the view
	NSColor *bevelColor = [NSColor whiteColor];
	NSRect bevelRect = [self bounds];
	bevelRect.size.height = 1.0;
	
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
	if (value)	[[self animator] setIllumination: 1.0];
	else		[[self animator] setIllumination: 0.0];
}

- (void) setIllumination: (CGFloat)newValue
{
	[super willChangeValueForKey: @"illumination"];
	illumination = newValue;
	[self setNeedsDisplay: YES];
	[super didChangeValueForKey: @"illumination"];
}
@end

@implementation BXFilterPortraitCell

- (void) awakeFromNib
{
	//Prevent the portrait from darkening when pressed in.
	[self setHighlightsBy: NSNoCellMask];
}

- (NSAttributedString *) attributedTitle
{
	NSFont *font;
	NSColor *textColor;
	
	if ([self state])
	{
		textColor = [NSColor whiteColor];
		font = [NSFont boldSystemFontOfSize: 0];
	}
	else
	{
		textColor = [NSColor lightGrayColor];
		font = [NSFont systemFontOfSize: 0];
	}
	
	NSShadow *textShadow = [[NSShadow new] autorelease];	
	[textShadow setShadowOffset: NSMakeSize(0.0, -1.0)];
	[textShadow setShadowBlurRadius: 2.0];
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
	theRect.origin.y = 72.0;
	return theRect;
}

- (void) drawWithFrame: (NSRect)frame inView: (BXFilterPortrait *)controlView
{
	if ([controlView illumination] > 0.0)
	{
		NSImage *spotlight = [NSImage imageNamed: @"GallerySpotlight.png"];
		[spotlight setFlipped: [controlView isFlipped]];
		[spotlight drawInRect: frame
					 fromRect: NSZeroRect
					operation: NSCompositePlusLighter
					 fraction: [controlView illumination]];
	}
	[super drawWithFrame: frame inView: controlView];
}

- (void) drawImage: (NSImage *)image	
		 withFrame: (NSRect)frame 
			inView: (BXFilterPortrait *)controlView
{
	if ([controlView illumination] < 0.9)
	{
		CGFloat shadeLevel = (1.0 - [controlView illumination]) * 0.25;
		NSColor *shade = [NSColor colorWithCalibratedWhite: 0.0 alpha: shadeLevel];
		
		image = [[image copy] autorelease];
		[image lockFocus];
			[NSGraphicsContext saveGraphicsState];
				[[NSGraphicsContext currentContext] setCompositingOperation: NSCompositeSourceAtop];
				[shade set];
				[NSBezierPath fillRect: frame];
			[NSGraphicsContext restoreGraphicsState];
		[image unlockFocus];
	}
	[super drawImage: image withFrame: frame inView: controlView];
}

@end