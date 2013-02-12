/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXExternalMT32 is a BXExternalMIDIDevice subclass for use with devices that are known to be
//MT32s. It has more accurate sysex delay calculations that allow for the processing delay
//of earlier-model MT32s.

#import "BXExternalMIDIDevice.h"


#define SYSEX_HEADER_LENGTH 5
#define MT32SYSEX_ADDRESS_LENGTH 3

@interface BXExternalMT32 : BXExternalMIDIDevice
@end