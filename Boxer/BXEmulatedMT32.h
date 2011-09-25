/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXEmulatedMT32 provides a BXMIDIDevice wrapper for the MUNT MT-32 emulator.
//It takes an optional delegate to which it sends notifications of LCD display messages.
//Unlike the other BXMIDIDevice classes, this currently feeds audio output back into
//DOSBox's own mixer.

#import <Foundation/Foundation.h>
#import "BXMIDIDevice.h"
#import "MT32Emu/mt32emu.h"
#import "mixer.h"


#pragma mark -
#pragma mark Error constants

extern NSString * const BXEmulatedMT32ErrorDomain;

enum {
    BXEmulatedMT32MissingROM,       //No ROMs were specified when initializing.
    BXEmulatedMT32CouldNotLoadROM   //The specified ROMs were invalid or could not be opened.
};


#pragma mark -
#pragma mark Interface declaration


@protocol BXEmulatedMT32Delegate;

@interface BXEmulatedMT32 : NSObject <BXMIDIDevice>
{
    NSString *_PCMROMPath;
    NSString *_controlROMPath;
    id <BXEmulatedMT32Delegate> _delegate;
    NSError *_synthError;
    
    //TODO: hide the following from Obj-C contexts
    MT32Emu::Synth *_synth;
    MixerChannel *_mixerChannel;
    
}

@property (copy, nonatomic) NSString *PCMROMPath;
@property (copy, nonatomic) NSString *controlROMPath;
@property (assign, nonatomic) id <BXEmulatedMT32Delegate> delegate;

- (id <BXMIDIDevice>) initWithPCMROM: (NSString *)PCMROM
                          controlROM: (NSString *)controlROM
                            delegate: (id <BXEmulatedMT32Delegate>)delegate
                               error: (NSError **)outError;

@end
