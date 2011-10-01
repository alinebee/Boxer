/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXDummyMIDIDevice.h"


@implementation BXDummyMIDIDevice

- (BOOL) supportsMT32Music          { return NO; }
- (BOOL) supportsGeneralMIDIMusic   { return NO; }

- (BOOL) isProcessing { return NO; }
- (NSDate *) dateWhenReady { return [NSDate distantPast]; }

- (void) handleMessage: (NSData *)message {}
- (void) handleSysex: (NSData *)message {}

- (void) pause {}
- (void) resume {}
- (void) close {}

@end
