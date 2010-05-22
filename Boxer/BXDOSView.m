/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDOSView.h"
#import "BXGeometry.h"
#import "BXRenderingLayer.h"
#import "BXFrameRateCounterLayer.h"
#import "BXValueTransformers.h"
#import "BXFrameBuffer.h"
#import "BXRenderer.h"

@implementation BXDOSLayerView
@synthesize renderingLayer, frameRateLayer;


- (void) awakeFromNib
{
	CGRect canvas = NSRectToCGRect([self bounds]);
	
	[self setWantsLayer: YES];
	
	[self setRenderingLayer: [BXRenderingLayer layer]];
	[renderingLayer setDelegate: self];
	[renderingLayer setFrame: canvas];
	[renderingLayer setAutoresizingMask: kCALayerWidthSizable | kCALayerHeightSizable];
	

	//Now add a layer for displaying the current framerate
	[self setFrameRateLayer: [BXFrameRateCounterLayer layer]];
	
	[frameRateLayer setOpacity: 0.75];
	[frameRateLayer setForegroundColor: CGColorGetConstantColor(kCGColorWhite)];
	[frameRateLayer setFontSize: 20.0];
	[frameRateLayer setAlignmentMode: kCAAlignmentRight];
	
	BXRollingAverageTransformer *frameRateSmoother = [[[BXRollingAverageTransformer alloc] initWithWindowSize: 10] autorelease];
	NSDictionary *bindingOptions = [NSDictionary dictionaryWithObjectsAndKeys:
									frameRateSmoother,	NSValueTransformerBindingOption,
									nil];
	
	[frameRateLayer bind: @"frameRate" toObject: renderingLayer withKeyPath: @"renderer.frameRate" options: bindingOptions];
	
	[frameRateLayer setBounds: CGRectMake(0, 0, 400, 20)];
	[frameRateLayer setAnchorPoint: CGPointMake(1, 0)];
	[frameRateLayer setPosition: CGPointMake(CGRectGetMaxX(canvas) - 10, CGRectGetMinY(canvas) + 10)];
	[frameRateLayer setAutoresizingMask: kCALayerMinXMargin | kCALayerMaxYMargin];
	
	//Hide the frame-rate display until it is toggled on by a menu action
	[frameRateLayer setHidden: YES];
	
	//Hide the rendering layer until we receive our first frame to draw
	[renderingLayer setHidden: YES];
	
	[[self layer] addSublayer: renderingLayer];
	[renderingLayer addSublayer: frameRateLayer];
}

- (void) dealloc
{
	[self setRenderingLayer: nil],	[renderingLayer release];
	[self setFrameRateLayer: nil],	[frameRateLayer release];
	[super dealloc];
}


- (void) updateWithFrame: (BXFrameBuffer *)frame
{
	[[renderingLayer renderer] updateWithFrame: frame];
	[renderingLayer setHidden: NO];
	[renderingLayer setNeedsDisplay];
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

- (void) setManagesAspectRatio: (BOOL)manage
{
	[self willChangeValueForKey: @"managesAspectRatio"];
	[[renderingLayer renderer] setMaintainsAspectRatio: manage];
	[self didChangeValueForKey: @"managesAspectRatio"];
}

- (BOOL) managesAspectRatio
{
	return [[renderingLayer renderer] maintainsAspectRatio];	
}

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
	
	if (![self renderingLayer] || [[self renderingLayer] isHidden])
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
	[[NSNotificationCenter defaultCenter] postNotificationName: @"BXDOSViewWillLiveResizeNotification" object: self];
}

- (void) viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	[[NSNotificationCenter defaultCenter] postNotificationName: @"BXDOSViewDidLiveResizeNotification" object: self];
}
@end