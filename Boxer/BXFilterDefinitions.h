/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFilterDefinitions defines strategies for the various filters, which determine when and how Boxer should
//apply them. These are mapped to BXFilterType constants by BXVideoHandler's _paramsForFilterType: method.
//Ugghhhhhhh.


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

//Filters officially supported by Boxer
//-------------------------------------

BXFilterDefinition BXFilterNormalParams = {
	BXFilterNormal,
	0.0f,
	NSZeroSize,
	0.0f,
	1,
	1
};

BXFilterDefinition BXFilterHQxParams = {
	BXFilterHQx,
	1.1f,
	NSMakeSize(320, 240),
	0.0f,
	2,
	3
};

BXFilterDefinition BXFilterMAMEParams = {
	BXFilterMAME,
	2.0f,
	NSMakeSize(320, 240),
	0.0f,
	2,
	3
};

BXFilterDefinition BXFilterTVScanlinesParams = {
	BXFilterTVScanlines,
	2.0f,
	NSMakeSize(400, 300),
	0.75f,
	2,
	3
};

BXFilterDefinition BXFilterRGBParams = {
	BXFilterRGB,
	2.0f,
	NSMakeSize(400, 300),
	0.25f,
	2,
	3
};


//Unused (by Boxer) filters
//-------------------------

BXFilterDefinition BXFilterSaIParams = {
	BXFilterSaI,
	2.0f,
	NSMakeSize(320, 240),
	0.0f,
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
