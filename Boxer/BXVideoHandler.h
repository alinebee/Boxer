/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXVideoHandler manages DOSBox's video and renderer state. Very little of its interface is
//exposed to Boxer's high-level Cocoa classes.

#import <Foundation/Foundation.h>

#if __cplusplus
#import "config.h"
#import "video.h"
#endif


typedef NSUInteger BXFilterType;

typedef struct {
	//The type constant from BXEmulator+BXRendering.h to which this definition corresponds. Not currently used.
	BXFilterType	filterType;
	
	//The minimum surface scale at which this filter should be applied.
	//Normally this is 2.0, so the filter only starts applying once the surface is two or more times the original resolution. If the filter scales down well (like HQx), this can afford to be lower than 2.
	CGFloat			minOutputScale;
	
	//The maximum game resolution at which this filter should be applied,
	//or NSZeroSize to apply to all resolutions.
	NSSize			maxResolution;
	
	//Normally, the filter size is always equal to the surface scale rounded up: so e.g. a surface that's 2.1 scale will get a 3x scaler.
	//surfaceScaleBias tweaks the point at which rounding up occurs: a bias of 0.5 will mean that 2.1-2.4 get rounded down to 2x while 2.5-2.9 get rounded up to 3x, whereas a bias of 1.0 means that the scale will always get rounded down. 0.0 gives the normal result.
	//Tweaking this is needed for filters that get really muddy if they're scaled down a lot, like the TV scanlines.
	CGFloat			outputScaleBias;
	
	//The minimum supported scaler transformation. Normally 2.
	NSUInteger		minFilterScale;
	
	//The maximum supported scaler transformation. Normally 3.
	NSUInteger		maxFilterScale;
} BXFilterDefinition;



@class BXEmulator;
@class BXFrameBuffer;

@interface BXVideoHandler : NSObject
{
	BXEmulator *emulator;
	BXFrameBuffer *frameBuffer;
	
	NSInteger currentVideoMode;
	BXFilterType filterType;
	BOOL aspectCorrected;
	BOOL frameInProgress;
	
#if __cplusplus
	//This is a C++ function pointer and should never be seen by Obj-C classes
	GFX_CallBack_t callback;
#endif
}

#pragma mark -
#pragma mark Properties

//Our parent emulator.
@property (assign) BXEmulator *emulator;

//The framebuffer we render our frames into.
@property (retain) BXFrameBuffer *frameBuffer;

//Whether to apply 4:3 aspect ratio correction to the rendered output.
@property (assign, getter=isAspectCorrected) BOOL aspectCorrected;

//The current rendering style as a DOSBox filter type constant.
@property (assign) BXFilterType filterType;

//The current DOSBox frameskip setting.
@property (assign) NSUInteger frameskip;

//Returns whether the chosen filter is actually being rendered. This will be NO if the current rendered
//size is smaller than the minimum size supported by the chosen filter.
@property (readonly) BOOL filterIsActive;

//Returns whether the emulator is currently rendering in a text-only graphics mode.
@property (readonly) BOOL isInTextMode;

//Returns the base resolution the DOS game is producing.
@property (readonly) NSSize resolution;


#pragma mark -
#pragma mark Control methods

//Stops any rendering in progress and reinitialises DOSBox's graphical subsystem.
- (void) reset;

@end


#if __cplusplus

#pragma mark -
#pragma mark Almost-private functions

//Functions in this interface should not be called outside of BXEmulator and BXCoalface.
@interface BXVideoHandler (BXVideoHandlerInternals)

//Called by BXEmulator to prepare the renderer for shutdown.
- (void) shutdown;

//Called by DOSBox to set the DOSBox renderer's scaling strategy.
- (void) applyRenderingStrategy;

//Called by DOSBox to convert an RGB value into a BGRA palette entry.
- (NSUInteger) paletteEntryWithRed: (NSUInteger)red
							 green: (NSUInteger)green
							  blue: (NSUInteger)blue;

- (void) prepareForOutputSize: (NSSize)outputSize
					  atScale: (NSSize)scale
				 withCallback: (GFX_CallBack_t)newCallback;

- (BOOL) startFrameWithBuffer: (void **)frameBuffer pitch: (NSUInteger *)pitch;
- (void) finishFrameWithChanges: (const uint16_t *)dirtyBlocks;

@end

#endif
