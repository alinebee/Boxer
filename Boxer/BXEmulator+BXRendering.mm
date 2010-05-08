/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulator+BXRendering.h"
#import "BXSession.h"
#import "BXSessionWindowController+BXRenderController.h"
#import "BXGeometry.h"
#import "BXFilterDefinitions.h"
#import "BXRenderer.h"
#import "BXFrameBuffer.h"

#import <SDL/SDL.h>
#import "config.h"
#import "video.h"
#import "render.h"
#import "vga.h"
#import "sdlmain.h"

//Renderer functions
//------------------

@implementation BXEmulator (BXRendering)

//Introspecting the rendering context
//-----------------------------------

//Returns the base resolution the DOS game is producing, before any scaling or filters are applied.
- (NSSize) resolution
{
	NSSize size = NSZeroSize;
	if ([self isExecuting])
	{
		size.width	= (CGFloat)render.src.width;
		size.height	= (CGFloat)render.src.height;
	}
	return size;
}

//Returns the DOS resolution after aspect-correction scaling has been applied, but before filters are applied.
- (NSSize) scaledResolution
{
	NSSize size = [self resolution];
	NSSize scale = [[self frameBuffer] intendedScale];
	size.width *= scale.width;
	size.height *= scale.height;
	
	return size;
}

//Returns the x and y scaling factor being applied to the final surface, compared to the original resolution.
- (NSSize) scale
{
	NSSize resolution	= [self resolution];
	NSSize renderedSize	= [[self renderer] viewport].size;
	return NSMakeSize(renderedSize.width / resolution.width, renderedSize.height / resolution.height);
}


//Returns the bit depth of the current screen. As of OS X 10.5.4, this is always 32.
- (NSInteger) screenDepth
{
	NSScreen *screen = [NSScreen deepestScreen];
	return NSBitsPerPixelFromDepth([screen depth]);
}


//Returns whether the emulator is currently rendering in a text-only graphics mode.
- (BOOL) isInTextMode
{
	BOOL textMode = NO;
	if ([self isExecuting])
	{
		switch (currentVideoMode)
		{
			case M_TEXT: case M_TANDY_TEXT: case M_HERC_TEXT: textMode = YES;
		}
	}
	return textMode;
}


//Toggles aspect ratio correction and resets the renderer to apply the change immediately.
- (void) setAspectCorrected: (BOOL)correct
{
	if (correct != [self isAspectCorrected])
	{
		[self willChangeValueForKey: @"aspectCorrected"];
		
		aspectCorrected = correct;
		[self resetRenderer];
		
		[self didChangeValueForKey: @"aspectCorrected"];
	}
}

//Chooses the specified filter, and resets the renderer to apply the change immediately.
- (void) setFilterType: (BXFilterType)type
{	
	if (type != filterType)
	{
		NSAssert1(type >= 0 && type <= sizeof(BXFilters), @"Invalid filter type provided to setFilterType: %i", type);
		
		[self willChangeValueForKey: @"filterType"];
		
		filterType = type;
		[self resetRenderer];
		
		[self didChangeValueForKey: @"filterType"];
	}
}

//Returns whether the chosen filter is actually being rendered.
- (BOOL) filterIsActive
{
	BOOL isActive = NO;
	if ([self isExecuting])
	{
		isActive = ([self filterType] == render.scale.op);
	}
	return isActive;
}


//Reinitialises DOSBox's graphical subsystem and redraws the render region.
//This is called after resizing the session window or toggling rendering options.
- (void) resetRenderer
{
	if ([self isExecuting]) GFX_ResetScreen();
}

- (NSSize) minRenderedSizeForFilterType: (BXFilterType) type
{
	BXFilterDefinition params	= [self _paramsForFilterType: type];
	NSSize scaledResolution		= [self scaledResolution];
	NSSize	minRenderedSize		= NSMakeSize(scaledResolution.width * params.minFilterScale,
											 scaledResolution.height * params.minFilterScale
											 );
	return minRenderedSize;
}
@end


@implementation BXEmulator (BXRenderingInternals)

//Called by BXEmulator to prepare the renderer for shutdown.
- (void) _shutdownRenderer
{
}

//Rendering output
//----------------

- (void) _prepareForOutputSize: (NSSize)outputSize atScale: (NSSize)scale
{
	//If we were in the middle of a frame then cancel it
	frameInProgress = NO;
	
	[[[self delegate] mainWindowController] resizeToAccommodateOutputSize: outputSize atScale: scale];
	
	[self setFrameBuffer: [[self renderer] bufferForOutputSize: outputSize atScale: scale]]; 

	//Synchronise our record of the current video mode with the new video mode
	if (currentVideoMode != vga.mode)
	{
		BOOL wasTextMode = [self isInTextMode];
		[self willChangeValueForKey: @"isInTextMode"];
		currentVideoMode = vga.mode;
		[self didChangeValueForKey: @"isInTextMode"];
		BOOL nowTextMode = [self isInTextMode];
		
		//Started up a graphical application
		if (wasTextMode && !nowTextMode)
			[self _postNotificationName: @"BXEmulatorDidStartGraphicalContext"
					   delegateSelector: @selector(didStartGraphicalContext:)
							   userInfo: nil];
		
		//Graphical application returned to text mode
		else if (!wasTextMode && nowTextMode)
			[self _postNotificationName: @"BXEmulatorDidEndGraphicalContext"
					   delegateSelector: @selector(didEndGraphicalContext:)
							   userInfo: nil];
	}
}

- (BOOL) _startFrameWithBuffer: (void **)buffer pitch: (NSUInteger *)pitch
{
	//Don't let a new frame start if one is already going.
	//This is merely mirroring a sanity flag in DOSBox and I'm not sure that the code
	//ever actually does this. 
	if (frameInProgress) 
	{
		NSLog(@"Tried to start a new frame while one was still in progress!");
		return NO;
	}
	
	if (![self frameBuffer])
	{
		NSLog(@"Tried to start a frame before any framebuffer was created!");
		return NO;
	}
	
	*buffer	= [[self frameBuffer] mutableBytes];
	*pitch	= [[self frameBuffer] pitch];
	
	frameInProgress = YES;
	return YES;
}

- (void) _finishFrameWithChanges: (const uint16_t *)dirtyBlocks
{
	if ([self frameBuffer] && dirtyBlocks)
	{
		[[self renderer] drawFrame: [self frameBuffer] dirtyRegions: dirtyBlocks];
	}
	frameInProgress = NO;
}


//Rendering strategy
//------------------

- (BXFilterDefinition) _paramsForFilterType: (BXFilterType)type
{
	NSAssert1(type >= 0 && type <= sizeof(BXFilters), @"Invalid filter type provided to paramsForFilterType: %i", type);
	
	return BXFilters[type];
}

- (void) _applyRenderingStrategy
{
	if (![self isExecuting]) return;
	
	//Work out how much we will need to scale the resolution to fit the viewport
	NSSize resolution	= [self resolution];
	NSSize viewportSize	= [[self renderer] viewport].size;
		
	BOOL useAspectCorrection	= [self _shouldUseAspectCorrectionForResolution: resolution];	
	NSInteger maxFilterScale	= [self _maxFilterScaleForResolution: resolution];
	
	//Start off with a passthrough filter as the default
	BXFilterType activeType		= BXFilterNormal;
	NSInteger filterScale		= 1;
	
	BXFilterType desiredType	= [self filterType];
	
	//Decide if we can use our selected filter at this scale, and if so at what scale
	if (desiredType != BXFilterNormal && [self _shouldApplyFilterType: desiredType fromResolution: resolution toViewport: viewportSize])
	{
		activeType = desiredType;
		//Now decide on what operation size the scaler should use
		filterScale = [self _filterScaleForType: activeType
								 fromResolution: resolution
									 toViewport: viewportSize];
	}
	else if ([self _shouldApplyFilterType: BXFilterNormal fromResolution: resolution toViewport: viewportSize])
	{
		//If a more advanced filter is inappropriate, we fall back to the normal filter at an appropriate scale.
		//(However, if the normal filter shouldn't be used either, then we apply 1x scaling - i.e. no filtering at all.)
		filterScale = [self _filterScaleForType: BXFilterNormal
								 fromResolution: resolution
									 toViewport: viewportSize];
	}

	
	//Make sure we don't go over the maximum size imposed by the OpenGL hardware
	filterScale = fmin(filterScale, maxFilterScale);
	
	
	//Finally, apply the values to DOSBox
	render.aspect		= useAspectCorrection;
	render.scale.forced	= YES;
	render.scale.size	= (Bitu)filterScale;
	render.scale.op		= (scalerOperation_t)activeType;
}

//Returns whether to apply 4:3 aspect ratio correction to the specified DOS resolution. Currently we ignore the resolution itself, and instead check the pixel aspect ratio from DOSBox directly, as this is based on more data than we have. If the pixel aspect ratio is not ~1 then correction is needed.
- (BOOL) _shouldUseAspectCorrectionForResolution: (NSSize)resolution
{
	BOOL useAspectCorrection = NO;
	if ([self isExecuting])
	{
		useAspectCorrection = [self isAspectCorrected] && (fabs(render.src.ratio - 1) > 0.01);
	}
	return useAspectCorrection;
}

//Return the appropriate filter size we should use to scale the given resolution up to the given viewport.
//This is usually the viewport height divided by the resolution height and rounded up, to ensure
//we're always rendering larger than we need so that the graphics are crisper when scaled down.
//However we finesse this for some filters that look like shit when scaled down too much.
//(We base this on height rather than width, so that we'll use the larger filter size for aspect-ratio corrected surfaces.)
- (NSInteger) _filterScaleForType: (BXFilterType)type
				   fromResolution: (NSSize)resolution
					   toViewport: (NSSize)viewportSize
{
	BXFilterDefinition params = [self _paramsForFilterType: type];
	
	NSSize scale = NSMakeSize(viewportSize.width / resolution.width,
							  viewportSize.height / resolution.height);
	
	NSInteger filterScale = ceil(scale.height - params.outputScaleBias);
	if (filterScale < params.minFilterScale) filterScale = params.minFilterScale;
	if (filterScale > params.maxFilterScale) filterScale = params.maxFilterScale;
	
	return filterScale;
}

//Returns whether our selected filter should be applied for the specified transformation.
- (BOOL) _shouldApplyFilterType: (BXFilterType)type
				 fromResolution: (NSSize)resolution
					 toViewport: (NSSize)viewportSize
{
	BXFilterDefinition params = [self _paramsForFilterType: type];

	//Disable scalers for high-resolution games
	if (!sizeFitsWithinSize(resolution, params.maxResolution)) return NO;
	
	NSSize scale = NSMakeSize(viewportSize.width / resolution.width,
							  viewportSize.height / resolution.height);
	
	//Scale is too small for filter to be applied
	if (scale.height < params.minOutputScale) return NO;
	
	//Scale is too large for filter to be worth applying
	if (params.maxOutputScale && scale.height > params.maxOutputScale) return NO;

	//If we got this far, go for it!
	return YES;
}


- (NSInteger) _maxFilterScaleForResolution: (NSSize)resolution
{
	NSSize maxFrameSize	= [[self renderer] maxFrameSize];
	//Work out how big a filter operation size we can use, given the maximum output size
	NSInteger maxScale		= floor(fmin(maxFrameSize.width / resolution.width, maxFrameSize.height / resolution.height));

	return maxScale;
}
@end