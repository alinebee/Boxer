/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXEmulator+BXRendering.h"
#import "BXSession.h"
#import "BXGeometry.h"
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

//Reinitialises DOSBox's graphical subsystem and redraws the render region.
- (void) resetRenderer
{
	if ([self isExecuting]) GFX_ResetScreen();
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
	
	//Check if we can reuse our existing framebuffer:
	if ([self frameBuffer] && NSEqualSizes(outputSize, [[self frameBuffer] resolution]))
	{
		//If we're staying at the same resolution, just update the scale of our existing framebuffer
		[[self frameBuffer] setIntendedScale: scale];
	}
	else
	{
		//Otherwise, create a new framebuffer
		BXFrameBuffer *newBuffer = [BXFrameBuffer bufferWithResolution: outputSize depth: 4 scale: scale];
		[self setFrameBuffer: newBuffer];
	}
	
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
		[[self delegate] frameComplete: [self frameBuffer]];
	}
	frameInProgress = NO;
}


//Rendering strategy
//------------------

- (void) _applyRenderingStrategy
{
	if (![self isExecuting]) return;
	
	NSSize resolution			= [self resolution];		
	BOOL useAspectCorrection	= [self _shouldUseAspectCorrectionForResolution: resolution];	
	
	//We do all our filtering in OpenGL now, so tell DOSBox to use the simplest rendering path
	BXFilterType activeType		= BXFilterNormal;
	NSInteger filterScale		= 1;
	
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

@end