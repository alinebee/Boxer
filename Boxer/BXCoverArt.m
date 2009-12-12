/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXCoverArt.h"
#import "NSBezierPath+MCAdditions.h"
#import "BXGeometry.h"

@implementation BXCoverArt

//We give gameboxes a fairly strong shadow to lift them out from light backgrounds
+ (NSShadow *) dropShadowForSize: (NSSize) iconSize
{
	if (iconSize.height < 32) return nil;
	
	CGFloat blurRadius	= MAX(1.0, iconSize.height / 32);
	CGFloat offset		= MAX(1.0, iconSize.height / 128);
	
	NSShadow *boxShadow = [[NSShadow new] autorelease];
	[boxShadow setShadowOffset: NSMakeSize(0, -offset)];
	[boxShadow setShadowBlurRadius: blurRadius];
	[boxShadow setShadowColor: [[NSColor blackColor] colorWithAlphaComponent: 0.85]];

	return boxShadow;
}

//We give gameboxes a soft white glow around the inside edge so that they show up well against dark backgrounds
+ (NSShadow *) innerGlowForSize: (NSSize) iconSize
{
	if (iconSize.height < 64) return nil;
	CGFloat blurRadius = MAX(1.0, iconSize.height / 64);

	NSShadow *boxGlow = [[NSShadow new] autorelease];
	[boxGlow setShadowOffset: NSZeroSize];
	[boxGlow setShadowBlurRadius: blurRadius];
	[boxGlow setShadowColor: [[NSColor whiteColor] colorWithAlphaComponent: 0.33]];
	
	return boxGlow;
}

+ (NSImage *) shineForSize: (NSSize) iconSize
{ 
	NSImage *shine = [NSImage imageNamed: @"BoxArtShine.png"];
	[shine setSize: iconSize];
	return shine;
}

+ (NSImageRep *) representationFromImage: (NSImage *)originalImage forSize: (NSSize) iconSize
{
	//Effects we'll be applying to the cover art
	NSImage *shine			= [self shineForSize: iconSize];
	NSShadow *dropShadow	= [self dropShadowForSize: iconSize];
	NSShadow *innerGlow		= [self innerGlowForSize: iconSize];

	//Allow enough room around the image for our drop shadow
	NSSize availableSize	= NSMakeSize(
		iconSize.width	- [dropShadow shadowBlurRadius] * 2,
		iconSize.height	- [dropShadow shadowBlurRadius] * 2
	);
	
	NSRect artFrame;
	//Scale the image proportionally to fit our target box size
	artFrame.size	= sizeToFitSize([originalImage size], availableSize);
	artFrame.origin	= NSMakePoint(
		//Center the box horizontally...
		(iconSize.width - artFrame.size.width) / 2,
		//...but put its baseline along the bottom, with enough room for the drop shadow
		([dropShadow shadowBlurRadius] - [dropShadow shadowOffset].height)
	);
	//Round the rect up to integral values, to avoid blurry subpixel lines
	artFrame = NSIntegralRect(artFrame);
	
	
	//Create a new empty canvas to draw into
	NSImage *canvas = [[NSImage alloc] initWithSize: iconSize];
	NSBitmapImageRep *rep;
	
	[canvas lockFocus];
		//Draw the original image into the appropriate space in the canvas, with our drop shadow
		[NSGraphicsContext saveGraphicsState];
			[dropShadow set];
			[originalImage drawInRect: artFrame fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0];
		[NSGraphicsContext restoreGraphicsState];
		
		//Draw the inner glow inside the box region
		[[NSBezierPath bezierPathWithRect: artFrame] fillWithInnerShadow: innerGlow];
		
		//Draw our pretty box shine into the box's region
		[shine drawInRect: artFrame fromRect: artFrame operation: NSCompositeSourceOver fraction: 0.25];
	
		//Finally, outline the box
		[[NSColor colorWithCalibratedWhite: 0 alpha: 0.33] set];
		[NSBezierPath setDefaultLineWidth: 1.0];
		[NSBezierPath strokeRect: NSInsetRect(artFrame, -0.5, -0.5)];
	
		//Capture the canvas as an NSBitmapImageRep
		rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect: NSMakeRect(0, 0, iconSize.width, iconSize.height)];
	[canvas unlockFocus];
	[canvas release];
	
	return [rep autorelease];
}

+ (NSImage *) coverArtFromImage: (NSImage *)image
{
	//If the image already has an alpha channel, then assume that it already has effects of its own and don't process it.
	if ([[image bestRepresentationForDevice: nil] hasAlpha]) return image;

	NSImage *coverArt = [[NSImage alloc] init];
	[coverArt addRepresentation: [self representationFromImage: image forSize: NSMakeSize(512, 512)]];
	[coverArt addRepresentation: [self representationFromImage: image forSize: NSMakeSize(256, 256)]];
	[coverArt addRepresentation: [self representationFromImage: image forSize: NSMakeSize(128, 128)]];
	[coverArt addRepresentation: [self representationFromImage: image forSize: NSMakeSize(32, 32)]];
	
	return [coverArt autorelease];
}

@end