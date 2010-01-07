/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFilterGallery.h"

@implementation BXFilterGallery
- (void) drawRect: (NSRect)dirtyRect
{
	NSImage *wallpaper	= [NSImage imageNamed: @"GalleryBkg.jpg"];
	NSColor *pattern	= [NSColor colorWithPatternImage: wallpaper];
	
	NSSize patternSize		= [wallpaper size];
	NSRect frame			= [self frame];
	
	NSPoint patternPhase	= NSMakePoint(
		//Center the pattern horizontally
		((frame.size.width - patternSize.width) / 2) + frame.origin.x,
		//Lock the pattern to the bottom of the view
		frame.origin.y
	);
	
	//Finally, draw the background.
	[NSGraphicsContext saveGraphicsState];
	[pattern set];
	[[NSGraphicsContext currentContext] setPatternPhase: patternPhase];
	[NSBezierPath fillRect: dirtyRect];
	[NSGraphicsContext restoreGraphicsState];
}
@end


@implementation BXFilterPortraitCell

//Overridden to reposition our title to occupy the bottom 48px of the button


- (NSRect) drawTitle: (NSAttributedString *)title
		   withFrame: (NSRect)frame
			  inView: (NSView *)controlView
{
	NSColor *textColor		= ([self state]) ? [NSColor whiteColor] : [NSColor lightGrayColor];
	NSShadow *textShadow	= [[NSShadow new] autorelease];

	[textShadow setShadowOffset: NSMakeSize(0.0, -1.0)];
	[textShadow setShadowBlurRadius: 2.0];
	[textShadow setShadowColor: [NSColor blackColor]];
	
	NSMutableAttributedString *modifiedTitle = [[title mutableCopy] autorelease];
	NSRange textRange = NSMakeRange(0, [title length]);
	
	[modifiedTitle addAttribute: NSForegroundColorAttributeName value: textColor range: textRange];
	[modifiedTitle addAttribute: NSShadowAttributeName value: textShadow range: textRange];
	frame.origin.y = 184.0;
	
	return [super drawTitle: modifiedTitle withFrame: frame inView: controlView];
}

- (void) drawImage: (NSImage *)image	
		 withFrame: (NSRect)frame 
			inView: (NSView *)controlView
{
	if ([self state])
	{
		//If we are active, draw the spotlight behind the button
		NSImage *spotlight = [NSImage imageNamed: @"GallerySpotlight.png"];
		[spotlight setFlipped: YES];
		[spotlight drawInRect: frame
					 fromRect: NSZeroRect
					operation: NSCompositeSourceOver
					 fraction: 1.0];
	}
	else
	{
		//If we are inactive, draw the image as darkened instead
		NSColor *shade	= [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.3];
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