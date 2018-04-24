/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Foundation/Foundation.h>
#import "BXMIDIDevice.h"

/// \c BXDummyMIDIDevice receives but ignores all MIDI events.
/// It is used as a placeholder when MIDI is disabled.
@interface BXDummyMIDIDevice : NSObject <BXMIDIDevice>
@end
