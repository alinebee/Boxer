/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFilterDefinitions defines strategies for the various filters, which determine when and how Boxer should
//apply them. These are mapped to BXFilterType constants by BXRenderer's _paramsForFilterType: method.

#import "BXEmulator+BXRendering.h"


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