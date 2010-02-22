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

//Returns the size of the output DOSBox is rendering after scalers and aspect correction are applied,
//but before SDL has scaled it to the final draw surface.
- (NSSize) renderedSize
{
	NSSize size = NSZeroSize;
	if ([self isExecuting])
	{
		size.width	= (CGFloat)sdl.draw.width	* (CGFloat)sdl.draw.scalex;
		size.height	= (CGFloat)sdl.draw.height	* (CGFloat)sdl.draw.scaley;
	}
	return size;
}

//Returns the final size of SDL's render region.
- (NSSize) surfaceSize
{
	NSSize size = NSZeroSize;
	if ([self isExecuting])
	{
		if ([self isFullScreen] && sdl.clip.w && sdl.clip.h)
		{
			size.width	= (CGFloat)sdl.clip.w;
			size.height	= (CGFloat)sdl.clip.h;
		}
		else
		{
			BXSessionWindowController *controller = [[self delegate] mainWindowController];
			size = [controller renderViewSize];
		}
	}
	return size;
}

//Returns the x and y scaling factor being applied to the final surface, compared to the original resolution.
- (NSSize) scale
{
	NSSize resolution	= [self resolution];
	NSSize surfaceSize	= [self surfaceSize];
	return NSMakeSize(surfaceSize.width / resolution.width, surfaceSize.height / resolution.height);
}


//Returns the size in pixels of the current screen, used when rendering to a fullscreen context. 
- (NSSize) fullScreenSize	{ return [[self targetForFullScreen] frame].size; }


//Returns the bit depth of the current screen. As of OS X 10.5.4, this is always 32.
- (NSInteger) screenDepth
{
	NSScreen *screen = [NSScreen deepestScreen];
	return NSBitsPerPixelFromDepth([screen depth]);
}

//The screen upon which we will put the fullscreen display context.
//To match SDL, this is defined as the screen with the menubar on it, which should match up to kCGDirectMainDisplay,
//which is what SDL in its infinite wisdom is hardcoded to do
- (NSScreen *)targetForFullScreen
{
	return ([[NSScreen screens] count] > 0) ? [[NSScreen screens] objectAtIndex: 0] : nil;
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
			NSSize minSize = [self minSurfaceSizeForFilterType: filterType];
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

//Redraws the render region, without reinitialising.
//This is called while resizing the session window to provide live updates.
- (void) redraw
{
	/*
	if (!sdl.surface) return;
	
	//Center the viewport in our current surface size
	NSRect canvas, viewport;
	canvas.size = ([self isFullScreen]) ? [self fullScreenSize] : [self surfaceSize];
	
	viewport.size = sizeToFitSize([self renderedSize], [self surfaceSize]);
	viewport = centerInRect(viewport, canvas);
	
	glViewport(viewport.origin.x, viewport.origin.y, viewport.size.width, viewport.size.height);

	if (sdl.opengl.framebuf)
	{
		//Fill the framebuffer with black
		glClearColor(0.0, 0.0, 0.0, 1.0);
		glClear(GL_COLOR_BUFFER_BIT);
		
		glCallList(sdl.opengl.displaylist);
		SDL_GL_SwapBuffers();
	}
	 */
}


- (NSSize) minSurfaceSizeForFilterType: (BXFilterType) type
{
	BXFilterDefinition params	= [self _paramsForFilterType: type];
	NSSize scaledResolution		= [self scaledResolution];
	NSSize	minSurfaceSize		= NSMakeSize(scaledResolution.width * params.minFilterSize,
											 scaledResolution.height * params.minFilterSize
											 );
	return minSurfaceSize;
}
@end


@implementation BXEmulator (BXRenderingInternals)

//Called by BXEmulator to prepare the renderer for shutdown.
- (void) _shutdownRenderer
{
	//By the time we get here, there's no SDL context left and we should already have left fullscreen
	//[self setFullScreen: NO];
	//[[[self delegate] mainWindowController] clearSDLView];
}

//Returns the maximum supported render size, decided by OpenGL's max surface size.
//This is applied internally as a hard limit to DOSBox's render size.
- (NSSize) _maxRenderedSize
{
	NSSize size = NSZeroSize;
	if ([self isExecuting])
	{
		size.width = size.height = (CGFloat)sdl.opengl.max_texsize;
	}
	return size;
}

//SDL surface strategy
//--------------------

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
		[[self renderer] _drawPixelData: (void *)sdl.opengl.framebuf dirtyLines: Scaler_ChangedLines];
		
		//TODO: this does not belong here
		BXSessionWindowController *controller = [[self delegate] mainWindowController];
		[[controller renderView] setNeedsDisplay: YES];
	}
}


//Initialises the SDL surface to which we shall render.
//Called by boxer_SetupSurfaceScaled which is in turn called from DOSBox gui/sdlmain.cpp. This entirely replaces the old GFX_SetupSurfaceScaled DOSBox function.
- (void) _initSDLSurfaceWithFlags: (NSInteger)flags
{
	if (![self isExecuting]) return;
	
	NSSize renderedSize	= [self renderedSize];
	NSSize surfaceSize	= [self _surfaceSizeForRenderedSize: renderedSize fromResolution: [self scaledResolution]];
	NSInteger bpp		= [self screenDepth];

	sdl.clip.x = 0;
	sdl.clip.y = 0;
	sdl.clip.w = (Uint16)surfaceSize.width;
	sdl.clip.h = (Uint16)surfaceSize.height;
	
	sdl.opengl.bilinear = [self _shouldUseBilinearForResolution: [self resolution] atSurfaceSize: surfaceSize];
	
	
	if ([self isFullScreen])
	{
		NSSize screenSize = [self fullScreenSize];
		
		flags |= SDL_FULLSCREEN|SDL_HWSURFACE;

		sdl.surface = SDL_SetVideoMode((int)screenSize.width, (int)screenSize.height, bpp, flags);
		
		//Center the actual draw surface on the screen
		if (sdl.surface && sdl.surface->flags & SDL_FULLSCREEN)
		{
			sdl.clip.x = (Sint16)((sdl.surface->w - sdl.clip.w) * 0.5);
			sdl.clip.y = (Sint16)((sdl.surface->h - sdl.clip.h) * 0.5);
		}
	}
	else
	{
		flags |= SDL_HWSURFACE;
		sdl.surface = SDL_SetVideoMode(sdl.clip.w, sdl.clip.h, bpp, flags);
	}
}

//Returns whether to apply bilinear filtering to the specified rendering size.
//We apply filtering only when the size is not an exact multiple of the base resolution.
- (BOOL) _shouldUseBilinearForResolution: (NSSize)resolution atSurfaceSize: (NSSize)surfaceSize
{
	return	((NSInteger)surfaceSize.width	% (NSInteger)resolution.width) || 
			((NSInteger)surfaceSize.height	% (NSInteger)resolution.height);
}

//Returns the size of surface that SDL should use for rendering DOSBox's output. In fullscreen mode, this is just the render size fitted to the screen resolution; in windowed mode we pass the calculation up to BXSessionWindowController, as it knows more about the desktop context than we do.
- (NSSize) _surfaceSizeForRenderedSize: (NSSize)renderedSize fromResolution: (NSSize)resolution
{
	NSSize surfaceSize;
	if ([self isFullScreen]) 
	{
		surfaceSize = sizeToFitSize(renderedSize, [self fullScreenSize]);
	}
	else
	{
		BXSessionWindowController *controller = [[self delegate] mainWindowController];
		surfaceSize = [controller viewSizeForScaledOutputSize: renderedSize minSize: resolution];
	}
	
	return surfaceSize;
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
	NSSize expectedRenderSize	= [self _probableSurfaceSizeForResolution: resolution];
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
	if (activeType == BXFilterNormal && (
		resolution.width >= 640 || resolution.height >= 400 ||
		![self _shouldUseBilinearForResolution: resolution atSurfaceSize: expectedRenderSize]
	))
	{
		filterScale = 1;
	}
	else
	{
		filterScale					= [self _sizeForFilterType: activeType atScale: scale];
		NSInteger maxFilterScale	= [self _maxFilterSizeForResolution: resolution];
		filterScale					= fmin(filterScale, maxFilterScale);
	}
	
	filterScale = 1;
	
	//Finally, apply the values to DOSBox
	render.aspect		= useAspectCorrection;
	render.scale.forced	= YES;
	render.scale.size	= (Bitu)filterScale;
	render.scale.op		= (scalerOperation_t)activeType;
}

//This 'predicts' the final surface size from very early in the render process, for applyRenderingStrategy to make decisions about filtering.
//Once all that shitty render-setup code is refactored, this will hopefully be unnecessary.
- (NSSize) _probableSurfaceSizeForResolution: (NSSize)resolution
{
	NSSize renderedSize			= resolution;
	BOOL useAspectCorrection	= [self _shouldUseAspectCorrectionForResolution: resolution];
	if ([self isExecuting])
	{
		if (useAspectCorrection) renderedSize.height *= render.src.ratio;
	}
	return [self _surfaceSizeForRenderedSize: renderedSize fromResolution: resolution];
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
	NSSize maxRenderedSize	= [self _maxRenderedSize];
	//Work out how big a filter operation size we can use given the maximum render size
	NSInteger maxFilterSize	= floor(fmin(maxRenderedSize.width / resolution.width, maxRenderedSize.height / resolution.height));
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
	BXEmulator *emulator	= [BXEmulator currentEmulator];
	[emulator _initSDLSurfaceWithFlags: (NSInteger)sdl_flags];
}

//Populates a pair of integers with the dimensions of the current render-surface
//This is called by GUI_StartUp in DOSBox's gui/sdlmain.cpp, when initialising OpenGL with a 'pioneer' surface to obtain OpenGL parameters
void boxer_copySurfaceSize(unsigned int * surfaceWidth, unsigned int * surfaceHeight)
{
	BXEmulator *emulator	= [BXEmulator currentEmulator];
	NSSize surfaceSize		= [emulator surfaceSize];
	
	*surfaceWidth	= (unsigned int)surfaceSize.width;
	*surfaceHeight	= (unsigned int)surfaceSize.height;
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