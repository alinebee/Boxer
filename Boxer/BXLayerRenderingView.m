/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXLayerRenderingView.h"
#import "BXRenderingLayer.h"
#import "BXFrameRateCounterLayer.h"
#import "BXValueTransformers.h"
#import "BXFrameBuffer.h"
#import "BXRenderer.h"
#import "BXDOSWindowController.h" //For notifications

@implementation BXLayerRenderingView
@synthesize renderingLayer, frameRateLayer;

- (id) initWithCoder: (NSCoder *)aDecoder
{
    if ((self = [super initWithCoder: aDecoder]))
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
        
        [[self layer] addSublayer: renderingLayer];
        [renderingLayer addSublayer: frameRateLayer];
    }
    return self;
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
	[[renderingLayer renderer] updateWithFrame: frame inGLContext: [[self openGLContext] CGLContextObj]];
    
	[renderingLayer setNeedsDisplay];
}

- (BXFrameBuffer *) currentFrame
{
	BXRenderer *renderer = [renderingLayer renderer];
    return [renderer currentFrame];
}

- (NSSize) viewportSize
{
	BXRenderer *renderer = [renderingLayer renderer];
	return NSSizeFromCGSize([renderer viewportForFrame: [self currentFrame]].size);
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
	[[renderingLayer renderer] setMaintainsAspectRatio: manage];
	[renderingLayer setNeedsDisplay];
}

- (BOOL) managesAspectRatio
{
	return [[renderingLayer renderer] maintainsAspectRatio];	
}

//Silly notifications to let the window controller know when a live resize operation is starting/stopping,
//so that it can clean up afterwards.
- (void) viewWillStartLiveResize
{	
	[super viewWillStartLiveResize];
	[[NSNotificationCenter defaultCenter] postNotificationName: BXViewWillLiveResizeNotification object: self];
}

- (void) viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	[[NSNotificationCenter defaultCenter] postNotificationName: BXViewDidLiveResizeNotification object: self];
}


- (BOOL) needsDisplayCaptureSuppression
{
	return NO;
}

@end
