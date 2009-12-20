/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFilterDefinitions defines strategies for the various filters, which determine when and how Boxer should
//apply them. These are mapped to BXFilterType constants by BXRenderer's paramsForFilterType: method.

#import "BXEmulator+BXRendering.h"

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


//Filters officially supported by Boxer
//-------------------------------------

BXFilterDefinition BXFilterNormalParams = {
	BXFilterNormal,
	0.0,
	0.0,
	1,
	3 //This supports up to 4 now, but 4 has proven to be very sluggish so is disabled for now
	  //Look into why this is - it shouldn't be a programming error in the filter itself, as the
	  //algorithm is extremely simple, but possibly a max texture-size problem
};

BXFilterDefinition BXFilterHQxParams = {
	BXFilterHQx,
	1.1,
	0.0,
	2,
	3
};

BXFilterDefinition BXFilterMAMEParams = {
	BXFilterMAME,
	2,
	0.0,
	2,
	3
};

BXFilterDefinition BXFilterTVScanlinesParams = {
	BXFilterTVScanlines,
	2,
	0.75,
	2,
	3
};

BXFilterDefinition BXFilterRGBParams = {
	BXFilterRGB,
	2,
	0.25,
	2,
	3
};


//Unused (by Boxer) filters
//-------------------------

BXFilterDefinition BXFilterSaIParams = {
	BXFilterSaI,
	2,
	0.0,
	2,
	2
};

BXFilterDefinition BXFilterSuperSaIParams		= BXFilterSaIParams;
BXFilterDefinition BXFilterSuperEagleParams		= BXFilterSaIParams;

//Advanced Interpolation appears to be based on the same algorithm as MAME
BXFilterDefinition BXFilterInterpolatedParams	= BXFilterMAMEParams;

BXFilterDefinition BXFilterScanlinesParams		= BXFilterTVScanlinesParams;



//Mapping table of filter definitions - the order corresponds to BXFilterType constants
const BXFilterDefinition BXFilters[BXFilterScanlines+1] = {
	BXFilterNormalParams,
	BXFilterMAMEParams,
	BXFilterInterpolatedParams,
	BXFilterHQxParams,
	BXFilterSaIParams,
	BXFilterSuperSaIParams,
	BXFilterSuperEagleParams,
	BXFilterTVScanlinesParams,
	BXFilterRGBParams,
	BXFilterScanlinesParams
};