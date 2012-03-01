/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXExternalMIDIDevice represents a connection to an external MIDI device (such as a real MT-32.)

#import <Foundation/Foundation.h>
#import <CoreMIDI/MIDIServices.h>
#import "BXMIDIDevice.h"

//The default seconds-per-byte delay to allow after sending a sysex.
//Equivalent to the MIDI 1.0 specified delay of 3125 bytes/sec.
#define BXExternalMIDIDeviceDefaultSysexRate 1.0f / 3125.0f

//A short delay between programmatically changing the volume and updating the device,
//to avoid rapid volume changes flooding the device with messages.
#define BXVolumeSyncDelay 0.05

@interface BXExternalMIDIDevice : NSObject <BXMIDIDevice>
{
	MIDIPortRef _port;
	MIDIClientRef _client;
	MIDIEndpointRef _destination;
    
    NSTimeInterval _secondsPerByte;
    
    NSDate *_dateWhenReady;
    
    float _volume;
    float _requestedVolume;
    NSTimer *_volumeSyncTimer;
}

//The destination this device is connecting to. Set at initialization time.
@property (readonly, nonatomic) MIDIEndpointRef destination;

//Declared as settable for the benefit of our subclasses
@property (copy, nonatomic) NSDate *dateWhenReady;

//The master volume assigned by the application, from 0.0 to 1.0.
@property (assign, nonatomic) float volume;

//The master volume requested by the MIDI-using application via sysex, from 0.0 to 1.0.
//This will be multiplied by @volume to arrive at the volume the device will be set to.
@property (assign, nonatomic) float requestedVolume;


#pragma mark -
#pragma mark Utility methods

//The descriptive client and port names to use for MIDI device connections.
//Has no effect on actual functionality.
+ (NSString *)defaultClientName;
+ (NSString *)defaultPortName;

//Returns how many seconds to allow for the external device to process the specified sysex.
//This is based on the time reported by the destination.
//Used to calculate dateWhenReady when sending sysex commands.
- (NSTimeInterval) processingDelayForSysex: (NSData *)sysex;


#pragma mark -
#pragma mark Initializers

- (id <BXMIDIDevice>) initWithDestination: (MIDIEndpointRef)destination
                                    error: (NSError **)outError;

- (id <BXMIDIDevice>) initWithDestinationAtIndex: (ItemCount)destIndex
                                           error: (NSError **)outError;

- (id <BXMIDIDevice>) initWithDestinationAtUniqueID: (MIDIUniqueID)uniqueID
                                              error: (NSError **)outError;

#pragma mark -
#pragma mark Volume control

//
- (void) scheduleVolumeSync;

//Called after a short delay when @volume is changed, to send the new volume
//to the external device. The delay prevents rapid minor volume changes from
//flooding the external device.
- (void) syncVolume;

@end
