/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXExternalMIDIDevice represents a connection to an external MIDI device such as a real MT-32.

#import <Foundation/Foundation.h>
#import <CoreMIDI/MIDIServices.h>
#import "BXMIDIDevice.h"


@interface BXExternalMIDIDevice : NSObject <BXMIDIDevice>
{
	MIDIPortRef _port;
	MIDIClientRef _client;
	MIDIEndpointRef _destination;
}

//The descriptive client and port names to use for MIDI device connections.
//Has no effect on actual functionality.
+ (NSString *)defaultClientName;
+ (NSString *)defaultPortName;

- (id <BXMIDIDevice>) initWithDestination: (MIDIEndpointRef)destination
                                    error: (NSError **)outError;

- (id <BXMIDIDevice>) initWithDestinationAtIndex: (ItemCount)destIndex
                                           error: (NSError **)outError;

- (id <BXMIDIDevice>) initWithDestinationAtUniqueID: (MIDIUniqueID)uniqueID
                                              error: (NSError **)outError;

@end
