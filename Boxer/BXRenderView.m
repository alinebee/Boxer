/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXRenderView.h"
#import "BXGeometry.h"
#import "BXRenderingLayer.h"

@implementation BXRenderView
@synthesize renderingLayer, frameRateLayer;


- (void) awakeFromNib
{
	[self setWantsLayer: YES];
	
	CALayer *parentLayer	= [self layer];
	CGRect canvas = [parentLayer bounds];
	
	[self setRenderingLayer: [BXRenderingLayer layer]];
	[renderingLayer setDelegate: self];
	
	[renderingLayer setNeedsDisplayOnBoundsChange: YES];
	[renderingLayer setOpaque: YES];
	[renderingLayer setAsynchronous: NO];
	
	[renderingLayer setFrame: canvas];
	[renderingLayer setAutoresizingMask: kCALayerWidthSizable | kCALayerHeightSizable];

	//Hide the layer until it has a frame to draw (it will unhide itself after that.)
	[renderingLayer setHidden: YES];
	[parentLayer addSublayer: renderingLayer];
	
	
	//Now add a layer for displaying the current framerate
	[self setFrameRateLayer: [CATextLayer layer]];
	
	[frameRateLayer setOpacity: 0.75];
	[frameRateLayer setForegroundColor: CGColorGetConstantColor(kCGColorWhite)];
	[frameRateLayer setFontSize: 20.0];
	[frameRateLayer setAlignmentMode: kCAAlignmentRight];
	
	[frameRateLayer bind: @"string" toObject: renderingLayer withKeyPath: @"frameRateInfo" options: nil];
	
	[frameRateLayer setBounds: CGRectMake(0, 0, 400, 20)];
	[frameRateLayer setAnchorPoint: CGPointMake(1, 0)];
	[frameRateLayer setPosition: CGPointMake(CGRectGetMaxX(canvas) - 10, CGRectGetMinY(canvas) + 10)];
	[frameRateLayer setAutoresizingMask: kCALayerMinXMargin | kCALayerMaxYMargin];
	
	//This can be toggled by a menu item
	[frameRateLayer setHidden: YES];
	
	[renderingLayer addSublayer: frameRateLayer];
}

- (IBAction) toggleFrameRate: (id) sender
{
	[[self frameRateLayer] setHidden: ![[self frameRateLayer] isHidden]];
}


#pragma -
#pragma mark Responder-related methods

- (BOOL) acceptsFirstResponder
{
	return YES;
}

//Pass on various events that would otherwise be eaten by the view
- (void) rightMouseDown: (NSEvent *)theEvent
{
	[[self nextResponder] rightMouseDown: theEvent];
}


#pragma -
#pragma mark Rendering methods

- (void) drawBackgroundInRect: (NSRect)dirtyRect
{
	//Cache the background gradient so we don't have to generate it each time
	static NSGradient *background = nil;
	if (background == nil)
	{
		NSColor *backgroundColor = [NSColor darkGrayColor];
		background = [[NSGradient alloc] initWithColorsAndLocations:
					  [backgroundColor shadowWithLevel: 0.5],	0.00,
					  backgroundColor,							0.98,
					  [backgroundColor shadowWithLevel: 0.4],	1.00,
					  nil];	
	}
	
	[background drawInRect: [self bounds] angle: 90];
	
	NSImage *brand = [NSImage imageNamed: @"Brand.png"];
	NSRect brandRegion;
	brandRegion.size = [brand size];
	brandRegion = centerInRect(brandRegion, [self bounds]);
	
	if (NSIntersectsRect(dirtyRect, brandRegion))
	{
		[brand drawInRect: brandRegion
				 fromRect: NSZeroRect
				operation: NSCompositeSourceOver
				 fraction: 1.0];	
	}		
}

- (void) drawRect: (NSRect)dirtyRect
{
	if ([[self renderingLayer] isHidden])
	{
		[NSBezierPath clipRect: dirtyRect];
		[self drawBackgroundInRect: dirtyRect];
	}
}

//Silly notifications to let the window controller know when a live resize operation is starting/stopping,
//so that it can clean up afterwards.
- (void) viewWillStartLiveResize
{	
	[super viewWillStartLiveResize];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"BXRenderViewWillLiveResizeNotification" object: self];
}

- (void) viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"BXRenderViewDidLiveResizeNotification" object: self];
}
@end