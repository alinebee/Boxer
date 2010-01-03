/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXBootlegCoverArt.h"

@implementation BXJewelCase

+ (NSString *)fontName	{ return @"Marker Felt Thin"; }

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

+ (NSImageRep *) representationWithTitle: (NSString *)title forSize: (NSSize) iconSize
{
	NSRect frame		= NSMakeRect(0, 0, iconSize.width, iconSize.height);
	NSRect textRegion	= [self textRegionForSize: iconSize];
	NSDictionary *textAttributes = [self textAttributesForSize: iconSize];
	
	NSImage *baseLayer	= [self baseLayerForSize: iconSize];
	NSImage *topLayer	= [self topLayerForSize: iconSize];
	
	//Create a new empty canvas to draw into
	NSImage *canvas = [[NSImage alloc] initWithSize: iconSize];
	NSBitmapImageRep *rep;
	
	[canvas lockFocus];
		[baseLayer drawInRect: frame fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0];
	
		[title drawInRect: textRegion withAttributes: textAttributes];
	
		[topLayer drawInRect: frame fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1.0];
	
		//Capture the canvas as an NSBitmapImageRep
		rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect: frame];
	[canvas unlockFocus];
	[canvas release];
	
	return [rep autorelease];
}

+ (NSImage *) coverArtWithTitle: (NSString *)title
{
	NSImage *coverArt = [[NSImage alloc] init];
	[coverArt addRepresentation: [self representationWithTitle: title forSize: NSMakeSize(128, 128)]];
	return [coverArt autorelease];
}

+ (NSImage *) baseLayerForSize:	(NSSize)size	{ return [NSImage imageNamed: @"CDCase.png"]; }
+ (NSImage *) topLayerForSize:	(NSSize)size	{ return [NSImage imageNamed: @"CDCover.png"]; }
+ (NSRect) textRegionForSize:	(NSSize)size	{ return NSMakeRect(22, 32, 92, 60); }

@end


@implementation BXDiskette

+ (NSImage *) baseLayerForSize:	(NSSize)size	{ return [NSImage imageNamed: @"Diskette.png"]; }
+ (NSImage *) topLayerForSize:	(NSSize)size	{ return [NSImage imageNamed: @"DisketteShine.png"]; }
+ (NSRect) textRegionForSize:	(NSSize)size	{ return NSMakeRect(24, 55, 80, 54); }
+ (CGFloat) lineHeightForSize:	(NSSize)size	{ return 18.0; }

@end