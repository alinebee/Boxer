/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXVideoHandler.h"
#import "BXEmulator.h"
#import "BXSession.h"
#import "BXFrameBuffer.h"
#import "BXGeometry.h"
#import "BXFilterDefinitions.h"

#import "render.h"
#import "vga.h"


#pragma mark -
#pragma mark Really genuinely private functions

@interface BXVideoHandler ()

- (BXFilterDefinition) _paramsForFilterType: (BXFilterType)filterType;

- (BOOL) _shouldUseAspectCorrectionForResolution: (NSSize)resolution;

- (BOOL) _shouldApplyFilterType: (BXFilterType)type
				 fromResolution: (NSSize)resolution
					 toViewport: (NSSize)viewportSize 
					 isTextMode: (BOOL)isTextMode;

- (NSInteger) _filterScaleForType: (BXFilterType)type
				   fromResolution: (NSSize)resolution
					   toViewport: (NSSize)viewportSize
					   isTextMode: (BOOL)isTextMode;

- (NSInteger) _maxFilterScaleForResolution: (NSSize)resolution;

@end


@implementation BXVideoHandler
@synthesize frameBuffer;
@synthesize emulator;
@synthesize aspectCorrected;
@synthesize filterType;

- (id) init
{
	if ((self = [super init]))
	{
		currentVideoMode = M_TEXT;
	}
	return self;
}

- (void) dealloc
{	
	[self setFrameBuffer: nil], [frameBuffer release];
	[super dealloc];
}

- (NSSize) resolution
{
	NSSize size = NSZeroSize;
	if ([[self emulator] isExecuting])
	{
		size.width	= (CGFloat)render.src.width;
		size.height	= (CGFloat)render.src.height;
	}
	return size;
}

//Returns whether the emulator is currently rendering in a text-only graphics mode.
- (BOOL) isInTextMode
{
	BOOL textMode = NO;
	if ([[self emulator] isExecuting])
	{
		switch (currentVideoMode)
		{
			case M_TEXT: case M_TANDY_TEXT: case M_HERC_TEXT: textMode = YES;
		}
	}
	return textMode;
}

- (NSUInteger) frameskip
{
	return (NSUInteger)render.frameskip.max;
}

- (void) setFrameskip: (NSUInteger)frameskip
{
	[self willChangeValueForKey: @"frameskip"];
	render.frameskip.max = (Bitu)frameskip;
	[self didChangeValueForKey: @"frameskip"];
}



//Toggles aspect ratio correction and resets the renderer to apply the change immediately.
- (void) setAspectCorrected: (BOOL)correct
{
	[self willChangeValueForKey: @"aspectCorrected"];
	if (correct != [self isAspectCorrected])
	{
		aspectCorrected = correct;
		[self reset];		
	}
	[self didChangeValueForKey: @"aspectCorrected"];
}

//Chooses the specified filter, and resets the renderer to apply the change immediately.
- (void) setFilterType: (BXFilterType)type
{	
	[self willChangeValueForKey: @"filterType"];
	if (type != filterType)
	{
		NSAssert1(type <= sizeof(BXFilters), @"Invalid filter type provided to setFilterType: %i", type);
				
		filterType = type;
		[self reset];
		
	}
	[self didChangeValueForKey: @"filterType"];
}

//Returns whether the chosen filter is actually being rendered.
- (BOOL) filterIsActive
{
	BOOL isActive = NO;
	if ([[self emulator] isExecuting])
	{
		isActive = ([self filterType] == (NSUInteger)render.scale.op);
	}
	return isActive;
}

//Reinitialises DOSBox's graphical subsystem and redraws the render region.
//This is called after resizing the session window or toggling rendering options.
- (void) reset
{
	if ([[self emulator] isExecuting])
	{
		if (frameInProgress) [self finishFrameWithChanges: NULL];
		
		if (callback) callback(GFX_CallBackReset);
		//CPU_Reset_AutoAdjust();
	}
}

- (void) shutdown
{
	[self finishFrameWithChanges: 0];
	if (callback) callback(GFX_CallBackStop);
}


#pragma mark -
#pragma mark DOSBox callbacks

- (void) prepareForOutputSize: (NSSize)outputSize atScale: (NSSize)scale withCallback: (GFX_CallBack_t)newCallback
{
	//If we were in the middle of a frame then cancel it
	frameInProgress = NO;
	
	callback = newCallback;
	
	//Check if we can reuse our existing framebuffer: if not, create a new one
	if (!NSEqualSizes(outputSize, [[self frameBuffer] size]))
	{
		BXFrameBuffer *newBuffer = [BXFrameBuffer bufferWithSize: outputSize depth: 4];
		[self setFrameBuffer: newBuffer];
	}
	[[self frameBuffer] setIntendedScale: scale];
	[[self frameBuffer] setBaseResolution: [self resolution]];
	
	
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
			[[self emulator] _postNotificationName: @"BXEmulatorDidStartGraphicalContext"
								  delegateSelector: @selector(didStartGraphicalContext:)
										  userInfo: nil];
		
		//Graphical application returned to text mode
		else if (!wasTextMode && nowTextMode)
			[[self emulator] _postNotificationName: @"BXEmulatorDidEndGraphicalContext"
								  delegateSelector: @selector(didEndGraphicalContext:)
										  userInfo: nil];
	}
}

- (BOOL) startFrameWithBuffer: (void **)buffer pitch: (NSUInteger *)pitch
{
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

- (void) finishFrameWithChanges: (const uint16_t *)dirtyBlocks
{
	if ([self frameBuffer] && dirtyBlocks)
	{
		//TODO: send a notification instead?
		[[[self emulator] delegate] frameComplete: [self frameBuffer]];
	}
	frameInProgress = NO;
}

- (NSUInteger) paletteEntryWithRed: (NSUInteger)red
							 green: (NSUInteger)green
							  blue: (NSUInteger)blue;
{
	//Copypasta straight from sdlmain.cpp.
	return ((blue << 0) | (green << 8) | (red << 16)) | (255 << 24);
}


#pragma mark -
#pragma mark Rendering strategy

- (void) applyRenderingStrategy
{
	//Work out how much we will need to scale the resolution to fit the viewport
	NSSize resolution			= [self resolution];	
	NSSize viewportSize			= [[[self emulator] delegate] viewportSize];
	
	BOOL isTextMode				= [self isInTextMode];
	BOOL useAspectCorrection	= [self _shouldUseAspectCorrectionForResolution: resolution];	
	NSInteger maxFilterScale	= [self _maxFilterScaleForResolution: resolution];	
	
	
	//Start off with a passthrough filter as the default
	BXFilterType activeType		= BXFilterNormal;
	NSInteger filterScale		= 1;
	BXFilterType desiredType	= [self filterType];
	
	//Decide if we can use our selected filter at this scale, and if so at what scale
	if (desiredType != BXFilterNormal &&
		[self _shouldApplyFilterType: desiredType
					  fromResolution: resolution
						  toViewport: viewportSize
						  isTextMode: isTextMode])
	{
		activeType = desiredType;
		//Now decide on what operation size the scaler should use
		filterScale = [self _filterScaleForType: activeType
								 fromResolution: resolution
									 toViewport: viewportSize
									 isTextMode: isTextMode];
	}
	
	//Make sure we don't go over the maximum size imposed by the OpenGL hardware
	filterScale = MIN(filterScale, maxFilterScale);
	
	
	//Finally, apply the values to DOSBox
	render.aspect		= useAspectCorrection;
	render.scale.forced	= YES;
	render.scale.size	= (Bitu)filterScale;
	render.scale.op		= (scalerOperation_t)activeType;
}

- (BXFilterDefinition) _paramsForFilterType: (BXFilterType)type
{
	NSAssert1(type <= sizeof(BXFilters), @"Invalid filter type provided to paramsForFilterType: %i", type);
	
	return BXFilters[type];
}

//Returns whether to apply 4:3 aspect ratio correction to the specified DOS resolution. Currently we ignore the resolution itself, and instead check the pixel aspect ratio from DOSBox directly, as this is based on more data than we have. If the pixel aspect ratio is not ~1 then correction is needed.
- (BOOL) _shouldUseAspectCorrectionForResolution: (NSSize)resolution
{
	BOOL useAspectCorrection = NO;
	if ([[self emulator] isExecuting])
	{
		useAspectCorrection = [self isAspectCorrected] && (ABS(render.src.ratio - 1) > 0.01);
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
					   isTextMode: (BOOL) isTextMode
{
	BXFilterDefinition params = [self _paramsForFilterType: type];
	
	NSSize scale = NSMakeSize(viewportSize.width / resolution.width,
							  viewportSize.height / resolution.height);
	
	NSUInteger filterScale = (NSUInteger)ceilf(scale.height - params.outputScaleBias);
	if (filterScale < params.minFilterScale) filterScale = params.minFilterScale;
	if (filterScale > params.maxFilterScale) filterScale = params.maxFilterScale;
	
	return filterScale;
}

//Returns whether our selected filter should be applied for the specified transformation.
- (BOOL) _shouldApplyFilterType: (BXFilterType)type
				 fromResolution: (NSSize)resolution
					 toViewport: (NSSize)viewportSize
					 isTextMode: (BOOL)isTextMode
{
	BXFilterDefinition params = [self _paramsForFilterType: type];
	
	//Disable scalers for high-resolution graphics modes
	//(We leave them available for text modes)
	if (!isTextMode && !sizeFitsWithinSize(resolution, params.maxResolution)) return NO;
	
	NSSize scale = NSMakeSize(viewportSize.width / resolution.width,
							  viewportSize.height / resolution.height);
	
	//Scale is too small for filter to be applied
	if (scale.height < params.minOutputScale) return NO;
	
	//If we got this far, go for it!
	return YES;
}

- (NSInteger) _maxFilterScaleForResolution: (NSSize)resolution
{
	NSSize maxFrameSize	= [[[self emulator] delegate] maxFrameSize];
	//Work out how big a filter operation size we can use, given the maximum output size
	NSInteger maxScale	= floorf(MIN(maxFrameSize.width / resolution.width, maxFrameSize.height / resolution.height));
	
	return maxScale;
}

@end
