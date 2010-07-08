/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXLayerRenderingView.h"
#import "BXRenderingLayer.h"
#import "BXFrameRateCounterLayer.h"
#import "BXValueTransformers.h"
#import "BXFrameBuffer.h"
#import "BXRenderer.h"

@implementation BXLayerRenderingView
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
	
	[frameRateLayer setOpacity: 0.75f];
	[frameRateLayer setForegroundColor: CGColorGetConstantColor(kCGColorWhite)];
	[frameRateLayer setFontSize: 20.0f];
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



//Pass on various events that would otherwise be eaten by the default NSView implementation
- (void) rightMouseDown: (NSEvent *)theEvent
{
	[[self nextResponder] rightMouseDown: theEvent];
}

#pragma mark -
#pragma mark Rendering methods

- (void) updateWithFrame: (BXFrameBuffer *)frame
{
	[[renderingLayer renderer] updateWithFrame: frame];
	[renderingLayer setHidden: NO];
	[renderingLayer setNeedsDisplay];
}

- (BXFrameBuffer *)currentFrame
{
	return [[renderingLayer renderer] currentFrame];
}

- (NSSize) viewportSize
{
	BXRenderer *renderer = [renderingLayer renderer];
	return NSSizeFromCGSize([renderer viewportForFrame: [renderer currentFrame]].size);
}

- (NSSize) maxFrameSize
{
	BXRenderer *renderer = [renderingLayer renderer];
	return NSSizeFromCGSize([renderer maxFrameSize]);
}

- (IBAction) toggleFrameRate: (id) sender
{
	[[self frameRateLayer] setHidden: ![[self frameRateLayer] isHidden]];
}

- (void) setManagesAspectRatio: (BOOL)manage
{
	[self willChangeValueForKey: @"managesAspectRatio"];
	[[renderingLayer renderer] setMaintainsAspectRatio: manage];
	[renderingLayer setNeedsDisplay];
	[self didChangeValueForKey: @"managesAspectRatio"];
}

- (BOOL) managesAspectRatio
{
	return [[renderingLayer renderer] maintainsAspectRatio];	
}

@end
