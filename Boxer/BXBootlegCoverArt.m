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
	return [NSColor colorWithCalibratedRed: 0.0
									 green: 0.1
									  blue: 0.2
									 alpha: 0.9];
}

+ (CGFloat) lineHeightForSize:	(NSSize)size	{ return 20.0; }
+ (CGFloat) fontSizeForSize:	(NSSize)size	{ return 14.0; }

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

+ (NSImage *) baseLayerForSize:	(NSSize)size	{ return [NSImage imageNamed: @"CDCase.png"]; }
+ (NSImage *) topLayerForSize:	(NSSize)size	{ return [NSImage imageNamed: @"CDCover.png"]; }

+ (NSRect) textRegionForRect:	(NSRect)frame	{ return NSMakeRect(22, 32, 92, 60); }



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
	NSRect textRegion	= [[self class] textRegionForRect: frame];
	NSDictionary *textAttributes = [[self class] textAttributesForSize: iconSize];
	
	NSImage *baseLayer	= [[self class] baseLayerForSize: iconSize];
	NSImage *topLayer	= [[self class] topLayerForSize: iconSize];
	
	[baseLayer drawInRect: frame fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0];
	[[self title] drawInRect: textRegion withAttributes: textAttributes];
	[topLayer drawInRect: frame fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0];
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
	NSImage *coverArt = [[NSImage alloc] init];
	[coverArt addRepresentation: [self representationForSize: NSMakeSize(128, 128)]];
	return [coverArt autorelease];
}

+ (NSImage *) coverArtWithTitle: (NSString *)coverTitle
{
	id generator = [[[self alloc] initWithTitle: coverTitle] autorelease];
	return [generator coverArt];
}

@end


@implementation BX35Diskette

+ (NSImage *) baseLayerForSize:	(NSSize)size	{ return [NSImage imageNamed: @"35Diskette.png"]; }
+ (NSImage *) topLayerForSize:	(NSSize)size	{ return [NSImage imageNamed: @"35DisketteShine.png"]; }
+ (CGFloat) lineHeightForSize:	(NSSize)size	{ return 18.0; }

+ (NSRect) textRegionForRect:	(NSRect)frame	{ return NSMakeRect(24, 55, 80, 54); }

@end

@implementation BX525Diskette

+ (NSImage *) baseLayerForSize:	(NSSize)size	{ return [NSImage imageNamed: @"525Diskette.png"]; }
+ (NSImage *) topLayerForSize:	(NSSize)size	{ return nil; }
+ (CGFloat) lineHeightForSize:	(NSSize)size	{ return 16.0; }
+ (CGFloat) fontSizeForSize:	(NSSize)size	{ return 12.0; }

+ (NSRect) textRegionForRect:	(NSRect)frame	{ return NSMakeRect(16, 90, 96, 32); }

@end