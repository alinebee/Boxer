/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXRendering category extends BXEmulator to control DOSBox's rendering output and impose
//Boxer's own custom rendering strategies. As such it often needs to talk directly to the
//window and view, and so there is signficant coupling between this and BXRenderController.


#import <Cocoa/Cocoa.h>
#import "BXEmulator.h"

//These constants are for reference and correspond directly to constants defined in DOSBox's render_scalers.h
enum {
	BXFilterNormal		= 0,
	BXFilterMAME		= 1,
	BXFilterInterpolated= 2,
	BXFilterHQx			= 3,
	BXFilterSaI			= 4,
	BXFilterSuperSaI	= 5,
	BXFilterSuperEagle	= 6,
	BXFilterTVScanlines	= 7,
	BXFilterRGB			= 8,
	BXFilterScanlines	= 9
};
typedef NSInteger BXFilterType;

typedef struct {
	//The type constant from BXEmulator+BXRendering.h to which this definition corresponds. Not currently used.
	BXFilterType	filterType;
	
	//The minimum surface scale at which this filter should be applied.
	//Normally this is 2.0, so the filter only starts applying once the surface is two or more times the original resolution. If the filter scales down well (like HQx), this can afford to be lower than 2.
	CGFloat			minSurfaceScale;
	
	//Normally, the filter size is always equal to the surface scale rounded up: so e.g. a surface that's 2.1 scale will get a 3x scaler.
	//surfaceScaleBias tweaks the point at which rounding up occurs: a bias of 0.5 will mean that 2.1-2.4 get rounded down to 2x while 2.5-2.9 get rounded up to 3x, whereas a bias of 1.0 means that the scale will always get rounded down. 0.0 gives the normal result.
	//Tweaking this is needed for filters that get really muddy if they're scaled down a lot, like the TV scanlines.
	CGFloat			surfaceScaleBias;
	
	//The minimum supported scaler transformation. Normally 2.
	NSInteger		minFilterSize;
	
	//The maximum supported scaler transformation. Normally 3.
	NSInteger		maxFilterSize;
} BXFilterDefinition;



//DOS renderer functions
//----------------------
@interface BXEmulator (BXRendering)


//Introspecting the rendering context
//-----------------------------------

//Returns the base resolution the DOS game is producing, before any scaling or filters are applied.
- (NSSize) resolution;

//Returns the DOS resolution after aspect-correction scaling has been applied, but before filters are applied.
- (NSSize) scaledResolution;

//Returns the size of the output DOSBox is rendering to an OpenGL texture: after scalers and aspect correction
//are applied but before we have scaled it to the final draw surface/fullscreen context.
- (NSSize) renderedSize;

//Returns the size in pixels of our final render region.
- (NSSize) surfaceSize;

//Returns the x and y scaling factor being applied to the final surface, compared to the original resolution.
- (NSSize) scale;

//Returns the size in pixels of the current screen, used when rendering to a fullscreen context. 
- (NSSize) fullScreenSize;
//Returns the bit depth of the current screen. As of OS X 10.5.4, this is always 32.
- (NSInteger) screenDepth;

//Returns the screen we will use for rendering to a fullscreen context. Because of crappy nearsighted SDL code,
//this is locked to the screen on which the session window first opened, not the screen on which it is currently displayed.
- (NSScreen *) targetForFullScreen;

//Returns whether the emulator is currently rendering in a text-only graphics mode.
- (BOOL) isInTextMode;


//Controlling the rendering context
//---------------------------------

//Reinitialises DOSBox's graphical subsystem and redraws the render region.
//This is called after resizing the session window or toggling rendering options.
- (void) resetRenderer;


//Gets/sets whether we are rendering to fullscreen.
- (BOOL) isFullScreen;
- (void) setFullScreen: (BOOL)fullscreen;

//Gets/sets the current rendering filter. See the BXFilterType constants above for available options.
- (BXFilterType) filterType;
- (void) setFilterType: (BXFilterType)filterType;

//Returns the minimum view size needed to use the specified filter type. 
- (NSSize)	minSurfaceSizeForFilterType: (BXFilterType) filterType;

//Returns whether the chosen filter is actually being rendered. This will be NO if our current render region
//is smaller than the minimum size supported by the chosen filter.
- (BOOL) filterIsActive;

//Gets/sets whether we use aspect ratio correction to stretch non-4:3 resolutions to 4:3.
- (BOOL) isAspectCorrected;
- (void) setAspectCorrected: (BOOL)correct;

@end


#if __cplusplus

//The methods in this category should not be called outside BXEmulator
@interface BXEmulator (BXRenderingInternals)

//Called by BXEmulator during shutdown to prepare the renderer for shutdown.
- (void) _shutdownRenderer;


//Internal functions for decisions about rendering
//------------------------------------------------

//Returns the maximum supported render size, decided by OpenGL's max surface size.
//This is applied internally as a hard limit to DOSBox's render size.
- (NSSize) _maxRenderedSize;

- (BXFilterDefinition) _paramsForFilterType: (BXFilterType)filterType;

- (void) _initSDLSurfaceWithFlags: (NSInteger)flags;

- (NSSize)	_surfaceSizeForRenderedSize:		(NSSize)renderedSize fromResolution: (NSSize)resolution;
- (BOOL)	_shouldUseBilinearForResolution:	(NSSize)resolution atSurfaceSize: (NSSize)surfaceSize;

- (void)	_applyRenderingStrategy;
- (NSSize)	_probableSurfaceSizeForResolution: (NSSize)resolution;
- (BOOL)	_shouldUseAspectCorrectionForResolution: (NSSize)resolution;

- (BOOL)		_shouldApplyFilterType:	(BXFilterType) filterType toScale: (NSSize)scale;
- (NSInteger)	_sizeForFilterType:	(BXFilterType) filterType atScale: (NSSize)scale;
- (NSInteger)	_maxFilterSizeForResolution: (NSSize)resolution;

@end

#endif