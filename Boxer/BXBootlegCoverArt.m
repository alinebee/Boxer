/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXBootlegCoverArt.h"

@implementation BXJewelCase
@synthesize title;

+ (NSString *) fontName	{ return @"Marker Felt Thin"; }

+ (NSColor *) textColor
{
	return [NSColor colorWithCalibratedRed: 0.0f
									 green: 0.1f
									  blue: 0.2f
									 alpha: 0.9f];
}

+ (CGFloat) lineHeightForSize:	(NSSize)size	{ return 20.0f; }
+ (CGFloat) fontSizeForSize:	(NSSize)size	{ return 14.0f; }

+ (NSDictionary *) textAttributesForSize: (NSSize)size
{
	CGFloat lineHeight	= [self lineHeightForSize: size];
	CGFloat fontSize	= [self fontSizeForSize: size];
	NSColor *color		= [self textColor];
	NSFont *font		= [NSFont fontWithName: [self fontName] size: fontSize];
	
	NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[style setAlignment: NSCenterTextAlignment];
	[style setMaximumLineHeight: lineHeight];
	[style setMinimumLineHeight: lineHeight];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
			style,	NSParagraphStyleAttributeName,
			font,	NSFontAttributeName,
			color,	NSForegroundColorAttributeName,
			[NSNumber numberWithInteger: 2],	NSLigatureAttributeName,
			//[NSNumber numberWithFloat: 0.1],	NSObliquenessAttributeName,
			nil];
}

+ (NSImage *) baseLayerForSize:	(NSSize)size	{ return [NSImage imageNamed: @"CDCase"]; }
+ (NSImage *) topLayerForSize:	(NSSize)size
{
	if (size.width >= 128)
		return [NSImage imageNamed: @"CDCover"];
	else
		return nil;
}

+ (NSRect) textRegionForRect: (NSRect)frame
{
	if (frame.size.width >= 128)
		return NSMakeRect(22.0f, 32.0f, 92.0f, 60.0f);
	else
		return NSZeroRect;
}


- (id) initWithTitle: (NSString *)coverTitle
{
	if ((self = [super init]))
	{
		[self setTitle: coverTitle];
	}
	return self;
}

- (void) drawInRect: (NSRect)frame
{
	NSSize iconSize		= frame.size;
	
	NSImage *baseLayer	= [[self class] baseLayerForSize: iconSize];
	NSImage *topLayer	= [[self class] topLayerForSize: iconSize];
	NSRect textRegion = [[self class] textRegionForRect: frame];

	if (baseLayer) [baseLayer drawInRect: frame
								fromRect: NSZeroRect
							   operation: NSCompositeSourceOver
								fraction: 1.0f];

	if (!NSEqualRects(textRegion, NSZeroRect))
	{
		NSDictionary *textAttributes = [[self class] textAttributesForSize: iconSize];
		[[self title] drawInRect: textRegion withAttributes: textAttributes];
	}

	if (topLayer) [topLayer drawInRect: frame
							  fromRect: NSZeroRect
							 operation: NSCompositeSourceOver
							  fraction: 1.0f];		

}

- (NSImageRep *) representationForSize: (NSSize)iconSize
{
	NSRect frame = NSMakeRect(0.0f, 0.0f, iconSize.width, iconSize.height);
	
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
	NSImage *coverArt = [[NSImage alloc] init];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(128, 128)]];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(32, 32)]];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(16, 16)]];
	return [coverArt autorelease];
}

+ (NSImage *) coverArtWithTitle: (NSString *)coverTitle
{
	id generator = [[[self alloc] initWithTitle: coverTitle] autorelease];
	return [generator coverArt];
}

@end


@implementation BX35Diskette

+ (NSImage *) baseLayerForSize:	(NSSize)size	{ return [NSImage imageNamed: @"35Diskette"]; }
+ (NSImage *) topLayerForSize:	(NSSize)size
{
	if (size.width >= 128)
		[NSImage imageNamed: @"35DisketteShine"];
	else
		return nil;
}
+ (CGFloat) lineHeightForSize:	(NSSize)size	{ return 18.0f; }

+ (NSRect) textRegionForRect: (NSRect)frame
{
	if (frame.size.width >= 128)
		return NSMakeRect(24.0f, 55.0f, 80.0f, 54.0f);
	else
		return NSZeroRect;
}
@end

@implementation BX525Diskette

+ (NSImage *) baseLayerForSize:	(NSSize)size	{ return [NSImage imageNamed: @"525Diskette"]; }
+ (NSImage *) topLayerForSize:	(NSSize)size	{ return nil; }
+ (CGFloat) lineHeightForSize:	(NSSize)size	{ return 16.0f; }
+ (CGFloat) fontSizeForSize:	(NSSize)size	{ return 12.0f; }

+ (NSRect) textRegionForRect: (NSRect)frame
{
	if (frame.size.width >= 128)
		return NSMakeRect(16.0f, 90.0f, 96.0f, 32.0f);
	else
		return NSZeroRect;
}
@end
