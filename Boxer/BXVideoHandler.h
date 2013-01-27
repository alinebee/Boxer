/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXVideoHandler manages DOSBox's video and renderer state. Very little of its interface is
//exposed to Boxer's high-level Cocoa classes.

#import <Foundation/Foundation.h>

#if __cplusplus
#import "config.h"
#import "video.h"
#endif

//These constants are for reference and correspond directly to constants defined in DOSBox's render_scalers.h
typedef enum {
	BXFilterNormal		= 0,
	BXFilterMAME		= 1,
	BXFilterInterpolated= 2,
	BXFilterHQx			= 3,
	BXFilterSaI			= 4,
	BXFilterSuperSaI	= 5,
	BXFilterSuperEagle	= 6,
	BXFilterTVScanlines	= 7,
	BXFilterRGB			= 8,
	BXFilterScanlines	= 9,
    BXMaxFilters
} BXFilterType;

typedef struct {
	//The type constant from BXEmulator+BXRendering.h to which this definition
	//corresponds. Not currently used.
	BXFilterType	filterType;
	
	//The minimum output scaling factor at which this filter should be applied.
	//Normally this is 2.0, so the filter is only applied when the output
	//resolution is two or more times the original resolution. If the filter
	//scales down well (like HQx), this can afford to be lower than 2.
	CGFloat			minOutputScale;
	
	//The maximum game resolution at which this filter should be applied,
	//or NSZeroSize to apply to all resolutions.
	NSSize			maxResolution;
	
	//Normally, the chosen filter size will be the output scaling factor rounded up:
	//so e.g. an output resolution that's 2.1 scale will get a 3x filter.
	//outputScaleBias tweaks the point at which rounding up occurs: a bias of 0.5 will
	//mean that 2.1-2.4 get rounded down to 2x while 2.5-2.9 get rounded up to 3x,
	//whereas a bias of 1.0 means that the scale will always get rounded down.
	//0.0 gives the normal result.
	//Tweaking this is needed for filters that get really muddy if they're scaled down
	//a lot, like the TV scanlines.
	CGFloat			outputScaleBias;
	
	//The minimum supported filter transformation. Normally 2.
	NSUInteger		minFilterScale;
	
	//The maximum supported filter transformation. Normally 3.
	NSUInteger		maxFilterScale;
} BXFilterDefinition;



@class BXEmulator;
@class BXVideoFrame;

@interface BXVideoHandler : NSObject
{
	__unsafe_unretained BXEmulator *_emulator;
	BXVideoFrame *_currentFrame;
	
	NSInteger _currentVideoMode;
	BXFilterType _filterType;
	BOOL _frameInProgress;
	
#if __cplusplus
	//This is a C++ function pointer and should never be seen by Obj-C classes
	GFX_CallBack_t _callback;
#endif
}

#pragma mark -
#pragma mark Properties

//Our parent emulator.
@property (assign, nonatomic) BXEmulator *emulator;

//The framebuffer we render our frames into.
@property (retain, nonatomic) BXVideoFrame *currentFrame;

//The current rendering style as a DOSBox filter type constant.
@property (assign, nonatomic) BXFilterType filterType;

//The current DOSBox frameskip setting.
@property (assign, nonatomic) NSUInteger frameskip;

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
