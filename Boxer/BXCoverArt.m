/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXCoverArt.h"
#import "NSBezierPath+MCAdditions.h"
#import "ADBGeometry.h"
#import "NSShadow+ADBShadowExtensions.h"
#import "ADBAppKitVersionHelpers.h"

@implementation BXCoverArt
@synthesize sourceImage;


//We give gameboxes a fairly strong shadow to lift them out from light backgrounds
+ (NSShadow *) dropShadowForSize: (NSSize)iconSize
{
	if (iconSize.height < 32) return nil;
	
	CGFloat blurRadius	= MAX(1.0f, iconSize.height / 32);
	CGFloat offset		= MAX(1.0f, iconSize.height / 128);
	
    return [NSShadow shadowWithBlurRadius: blurRadius
                                   offset: NSMakeSize(0, -offset)
                                    color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.85f]];
}

//We give gameboxes a soft white glow around the inside edge so that they show up well against dark backgrounds
+ (NSShadow *) innerGlowForSize: (NSSize)iconSize
{
	if (iconSize.height < 64) return nil;
	CGFloat blurRadius = MAX(1.0f, iconSize.height / 64);
	
    return [NSShadow shadowWithBlurRadius: blurRadius
                                   offset: NSZeroSize
                                    color: [NSColor colorWithCalibratedWhite: 1 alpha: 0.33f]];
}

+ (NSImage *) shineForSize: (NSSize)iconSize
{ 
	NSImage *shine = [[NSImage imageNamed: @"BoxArtShine"] copy];
	[shine setSize: iconSize];
	return [shine autorelease];
}

- (id) initWithSourceImage: (NSImage *)image
{
	if ((self = [super init]))
	{
		[self setSourceImage: image];
	}
	return self;
}

- (void) drawInRect: (NSRect)frame
{
	//Switch to high-quality interpolation before we begin, and restore it once we're done
	//(this is not stored by saveGraphicsState/restoreGraphicsState unfortunately)
	NSImageInterpolation oldInterpolation = [[NSGraphicsContext currentContext] imageInterpolation];
	[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
	
	NSSize iconSize	= frame.size;
	NSImage *image	= [self sourceImage];
	
	//Effects we'll be applying to the cover art
	NSImage *shine			= [[self class] shineForSize: iconSize];
	NSShadow *dropShadow	= [[self class] dropShadowForSize: iconSize];
	NSShadow *innerGlow		= [[self class] innerGlowForSize: iconSize];
	
	//NOTE: drawInRect:fromRect:operation:fraction: misbehaves on 10.5 in that
	//it caches what it draws and may use that for future draw operations
	//instead of other, more suitable representations of that image.
	//To work around this, we draw a copy of the image instead of the original.
	//Fuck 10.5.
	if (isRunningOnLeopard())
	{
		image = [[image copy] autorelease];
		shine = [[shine copy] autorelease];
	}
	
	//Allow enough room around the image for our drop shadow
	NSSize availableSize	= NSMakeSize(
		iconSize.width	- [dropShadow shadowBlurRadius] * 2,
		iconSize.height	- [dropShadow shadowBlurRadius] * 2
	);

	NSRect artFrame;
	//Scale the image proportionally to fit our target box size
	artFrame.size	= sizeToFitSize([image size], availableSize);
	artFrame.origin	= NSMakePoint(
		//Center the box horizontally...
		(iconSize.width - artFrame.size.width) / 2,
		//...but put its baseline along the bottom, with enough room for the drop shadow
		([dropShadow shadowBlurRadius] - [dropShadow shadowOffset].height)
	);
	//Round the rect up to integral values, to avoid blurry subpixel lines
	artFrame = NSIntegralRect(artFrame);
	
	//Draw the original image into the appropriate space in the canvas, with our drop shadow
	[NSGraphicsContext saveGraphicsState];
		[dropShadow set];
		[image drawInRect: artFrame
				 fromRect: NSZeroRect
				operation: NSCompositeSourceOver
				 fraction: 1.0f];
	[NSGraphicsContext restoreGraphicsState];
	
	//Draw the inner glow inside the box region
	[[NSBezierPath bezierPathWithRect: artFrame] fillWithInnerShadow: innerGlow];
	
	//Draw our pretty box shine into the box's region
	[shine drawInRect: artFrame
			 fromRect: artFrame
			operation: NSCompositeSourceOver
			 fraction: 0.25f];
	
	//Finally, outline the box
	[[NSColor colorWithCalibratedWhite: 0.0f alpha: 0.33f] set];
	[NSBezierPath setDefaultLineWidth: 1.0f];
	[NSBezierPath strokeRect: NSInsetRect(artFrame, -0.5f, -0.5f)];
	
	[[NSGraphicsContext currentContext] setImageInterpolation: oldInterpolation];
}

- (NSImageRep *) representationForSize: (NSSize)iconSize
{	
	NSRect frame = NSMakeRect(0, 0, iconSize.width, iconSize.height);

	//Create a new empty canvas to draw into
	NSImage *canvas = [[NSImage alloc] initWithSize: iconSize];
	
	[canvas lockFocus];
		[self drawInRect: frame];
		NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect: frame];
	[canvas unlockFocus];
	[canvas release];
	
	return [rep autorelease];
}

- (NSImage *) coverArt
{
	NSImage *image = [self sourceImage];
	
	//If our source image could not be read, then bail out.
	if (![image isValid]) return nil;
	
	//If our source image already has transparency data,
	//then assume that it already has effects of its own applied and don't process it.
	if ([[self class] imageHasTransparency: image]) return image;
	
	NSImage *coverArt = [[NSImage alloc] init];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(512, 512)]];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(256, 256)]];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(128, 128)]];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(32, 32)]];
	
	return [coverArt autorelease];
}

+ (NSImage *) coverArtWithImage: (NSImage *)image
{
	id generator = [[[self alloc] initWithSourceImage: image] autorelease];
	return [generator coverArt];
}

+ (BOOL) imageHasTransparency: (NSImage *)image
{
	BOOL hasTranslucentPixels = NO;

	//Only bother testing transparency if the image has an alpha channel
	if ([[[image representations] lastObject] hasAlpha])
	{
		NSSize imageSize = [image size];
		
		//Test 5 pixels in an X pattern: each corner and right in the center of the image.
		NSPoint testPoints[5] = {
			NSMakePoint(0,						0),
			NSMakePoint(imageSize.width - 1.0f,	0),
			NSMakePoint(0,						imageSize.height - 1.0f),
			NSMakePoint(imageSize.width - 1.0f,	imageSize.height - 1.0f),
			NSMakePoint(imageSize.width * 0.5f,	imageSize.height * 0.5f)
		};
		NSInteger i;
						
		[image lockFocus];
		for (i=0; i<5; i++)
		{
			//If any of the pixels appears to be translucent, then stop looking further.
			NSColor *pixel = NSReadPixel(testPoints[i]);
			if (pixel && [pixel alphaComponent] < 0.9)
			{
				hasTranslucentPixels = YES;
				break;
			}
		}
		[image unlockFocus];
	}

	return hasTranslucentPixels;
}

@end
