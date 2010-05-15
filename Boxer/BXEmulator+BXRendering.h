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


//DOS renderer functions
//----------------------
@interface BXEmulator (BXRendering)

//Introspecting the rendering context
//-----------------------------------

//Returns the base resolution the DOS game is producing, before any scaling or filters are applied.
- (NSSize) resolution;

//Returns whether the emulator is currently rendering in a text-only graphics mode.
- (BOOL) isInTextMode;


//Controlling the rendering context
//---------------------------------

//Reinitialises DOSBox's graphical subsystem and redraws the render region.
//This is called after resizing the session window or toggling rendering options.
- (void) resetRenderer;

@end


#if __cplusplus

//The methods in this category should not be called outside BXEmulator
@interface BXEmulator (BXRenderingInternals)

//Called by BXEmulator during shutdown to prepare the renderer for shutdown.
- (void) _shutdownRenderer;


//Internal functions for decisions about rendering
//------------------------------------------------

- (void) _applyRenderingStrategy;
- (BOOL) _shouldUseAspectCorrectionForResolution: (NSSize)resolution;

- (void) _prepareForOutputSize: (NSSize)outputSize atScale: (NSSize)scale;
- (BOOL) _startFrameWithBuffer: (void **)frameBuffer pitch: (NSUInteger *)pitch;
- (void) _finishFrameWithChanges: (const uint16_t *)dirtyBlocks;

@end

#endif