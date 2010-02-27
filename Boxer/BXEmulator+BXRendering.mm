/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulator+BXRendering.h"
#import "BXSession.h"
#import "BXSessionWindowController+BXRenderController.h"
#import "BXSessionWindow.h"
#import "BXGeometry.h"

#import "boxer.h"
#import "render.h"
#import "video.h"
#import "vga.h"
#import "sdlmain.h"
#import "BXFilterDefinitions.h"
#import "BXRenderer.h"


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
	if ([self isExecuting])
	{
		if (sdl.draw.scalex > 0) size.width *= sdl.draw.scalex;
		if (sdl.draw.scaley > 0) size.height *= sdl.draw.scaley;
	}
	return size;
}

//Returns the x and y scaling factor being applied to the final surface, compared to the original resolution.
- (NSSize) scale
{
	NSSize resolution	= [self resolution];
	NSSize renderedSize	= [[self renderer] viewportSize];
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


//Controlling the rendering context
//---------------------------------

- (void) setFullScreen: (BOOL)fullscreen
{
	if ([self isExecuting] && [self isFullScreen] != fullscreen)
	{
		[self willChangeValueForKey: @"fullScreen"];
		//Fix the hanging cursor in fullscreen mode
		if (fullscreen && CGCursorIsVisible())		[NSCursor hide];
		GFX_SwitchFullScreen();
		if (!fullscreen && !CGCursorIsVisible())	[NSCursor unhide];
		
		[self didChangeValueForKey: @"fullScreen"];
	}
}

- (BOOL) isFullScreen
{
	BOOL fullscreen = NO;
	if ([self isExecuting])
	{
		fullscreen = (BOOL)sdl.desktop.fullscreen;
	}
	return fullscreen;
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
		
		//If the view is too small to apply the filter choice,
		//then try to resize it to an appropriate size
		if ([self _shouldApplyFilterType: type toScale: [self scale]])
		{
			[self resetRenderer];	
		}
		else
		{
			NSSize minSize = [self minRenderedSizeForFilterType: filterType];
			[[[self delegate] mainWindowController] resizeToAccommodateViewSize: minSize];
		}
		
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
	NSSize	minRenderedSize		= NSMakeSize(scaledResolution.width * params.minFilterSize,
											 scaledResolution.height * params.minFilterSize
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

- (NSUInteger) _prepareRenderContext
{
	NSSize outputSize	= NSMakeSize((CGFloat)sdl.draw.width, (CGFloat)sdl.draw.height);
	NSSize scale		= NSMakeSize((CGFloat)sdl.draw.scalex, (CGFloat)sdl.draw.scaley);
	
	[[[self delegate] mainWindowController] resizeToAccommodateOutputSize: outputSize atScale: scale];
	[[self renderer] prepareForOutputSize: outputSize atScale: scale];
	
	sdl.opengl.framebuf = malloc(sdl.draw.width * sdl.draw.height * 4);
	sdl.opengl.pitch = sdl.draw.width * 4;
	sdl.desktop.type = SCREEN_OPENGL;
	sdl.active = YES;
	
	if (!sdl.mouse.autoenable) SDL_ShowCursor(sdl.mouse.autolock ? SDL_DISABLE: SDL_ENABLE);

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
	
	return GFX_CAN_32 | GFX_SCALING;
}

- (void) _updateRenderContext
{
	if (sdl.opengl.framebuf && Scaler_ChangedLines)
	{
		[[self renderer] drawPixelData: (void *)sdl.opengl.framebuf dirtyBlocks: Scaler_ChangedLines];
	}
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
	
	//Work out how much we will need to scale the resolution to fit our likely surface
	NSSize resolution			= [self resolution];
	NSSize expectedRenderSize	= [self _probableRenderedSizeForResolution: resolution];
	NSSize scale				= NSMakeSize(expectedRenderSize.width	/ resolution.width,
											 expectedRenderSize.height	/ resolution.height);
		
	BOOL useAspectCorrection	= [self _shouldUseAspectCorrectionForResolution: resolution];
	
	//Decide if we can use our selected scaler at this scale,
	//reverting to the normal filter if we can't
	BXFilterType activeType = [self filterType];
	if (![self _shouldApplyFilterType: activeType toScale: scale]) activeType = BXFilterNormal;
		
	//Now decide on what operation size this scaler should use
	//If we're using a flat scaling filter and bilinear filtering isn't necessary for the target size
	//(or the base resolution is large enough for scaling to be too slow), then speed things up
	//by using 1x scaling and letting OpenGL do the work.
	NSInteger filterScale;
	if (activeType == BXFilterNormal)
	{
		filterScale = 1;
	}
	else
	{
		filterScale					= [self _sizeForFilterType: activeType atScale: scale];
		NSInteger maxFilterScale	= [self _maxFilterSizeForResolution: resolution];
		filterScale					= fmin(filterScale, maxFilterScale);
	}
	
	//Finally, apply the values to DOSBox
	render.aspect		= useAspectCorrection;
	render.scale.forced	= YES;
	render.scale.size	= (Bitu)filterScale;
	render.scale.op		= (scalerOperation_t)activeType;
}

//This 'predicts' the final rendered size from very early in the render process, for applyRenderingStrategy to make decisions about how and when to filter.
//Once all that shitty render-setup code is refactored, this will hopefully be unnecessary.
- (NSSize) _probableRenderedSizeForResolution: (NSSize)resolution
{
	NSSize outputSize			= resolution;
	BOOL useAspectCorrection	= [self _shouldUseAspectCorrectionForResolution: resolution];
	if ([self isExecuting])
	{
		if (useAspectCorrection) outputSize.height *= render.src.ratio;
	}
	
	BXSessionWindowController *controller = [[self delegate] mainWindowController];
	return [controller viewSizeForScaledOutputSize: outputSize minSize: resolution];
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

//Return the appropriate filter size for the given scale. This is usually the scale rounded up, to ensure we're always rendering larger than we need so that the graphics are crisper when scaled down. However we finesse this for some filters that look like shit when scaled down too much.
//We base this on height rather than width, so that we'll use the larger filter size for aspect-ratio corrected surfaces.
- (NSInteger) _sizeForFilterType: (BXFilterType) type atScale: (NSSize)scale
{	
	BXFilterDefinition params = [self _paramsForFilterType: type];
	
	NSInteger filterSize = ceil(scale.height - params.surfaceScaleBias);
	if (filterSize < params.minFilterSize)	filterSize = params.minFilterSize;
	if (filterSize > params.maxFilterSize)	filterSize = params.maxFilterSize;
	return filterSize;
}

- (NSInteger) _maxFilterSizeForResolution: (NSSize)resolution
{
	NSSize maxOutputSize	= [[self renderer] maxOutputSize];
	//Work out how big a filter operation size we can use given the maximum render size
	NSInteger maxFilterSize	= floor(fmin(maxOutputSize.width / resolution.width, maxOutputSize.height / resolution.height));
	return maxFilterSize;
}


//Returns whether our selected filter should be applied to the specified scale.
- (BOOL) _shouldApplyFilterType: (BXFilterType) type toScale: (NSSize)scale
{
	return (scale.height >= [self _paramsForFilterType: type].minSurfaceScale);
}
@end


//Bridge functions
//----------------
//DOSBox uses these to call relevant methods on the current Boxer emulation context

//Applies Boxer's rendering settings when reinitializing the DOSBox renderer
//This is called by RENDER_Reset in DOSBox's gui/render.cpp
void boxer_applyRenderingStrategy()	{ [[BXEmulator currentEmulator] _applyRenderingStrategy]; }

//Returns the colourdepth of the most colourful screen
//This is called by GUI_StartUp in DOSBox's gui/sdlmain.cpp
Bit8u boxer_screenColorDepth()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return (Bit8u)[emulator screenDepth];
}

//Initialises a new SDL surface to Boxer's specifications
//This is called by GFX_SetupSurfaceScaled in DOSBox's gui/sdlmain.cpp
void boxer_setupSurfaceScaled(Bit32u sdl_flags, Bit32u bpp)
{
	//This should never ever be used any longer
}

//Populates a pair of integers with the dimensions of the current render-surface
//This is called by GUI_StartUp in DOSBox's gui/sdlmain.cpp, when initialising OpenGL with a 'pioneer' surface to obtain OpenGL parameters
void boxer_copySurfaceSize(unsigned int * surfaceWidth, unsigned int * surfaceHeight)
{
	//This should never ever be used any longer
}

Bitu boxer_prepareRenderContext()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _prepareRenderContext];
}

void boxer_updateRenderContext()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _updateRenderContext];
}