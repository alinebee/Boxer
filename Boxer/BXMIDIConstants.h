/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//MIDI-related constants for General MIDI and MT-32 messages.

#define BXSysexStart 0xF0
#define BXSysexEnd 0xF7

//MIDI messages use 7 bits, but must be sent via byte arrays.
//This mask is for clearing the 8th and higher bits of the byte.
#define BXMIDIBitmask 0xFFFFFF80


#pragma mark -
#pragma mark General MIDI sysex message codes

#define BXGeneralMIDISysexNonRealtime 0x7E
#define BXGeneralMIDISysexRealtime 0x7F

#define BXGeneralMIDISysexAllChannels 0x7F
#define BXGeneralMIDISysexDeviceControl 0x04
#define BXGeneralMIDISysexMasterVolume 0x01

#define BXGeneralMIDIMaxMasterVolume 0x3FFF //16383

#pragma mark -
#pragma mark Roland sysex message format

//Start byte, manufacturer ID, device ID, model ID, message Type
#define BXRolandSysexHeaderLength 5
//High byte, middle byte, low byte
#define BXRolandSysexAddressLength 3
//High byte, middle byte, low byte
#define BXRolandSysexRequestSizeLength 3
//Checksum, end byte
#define BXRolandSysexTailLength 2


#define BXRolandMaxMasterVolume 100

#define BXRolandSysexChecksumModulus 128

#define BXSysexManufacturerIDRoland 0x41
#define BXSysexManufacturerIDNonRealtime 0x7E
#define BXSysexManufacturerIDRealtime 0x7F

#define BXRolandSysexModelIDMT32 0x16
#define BXRolandSysexModelIDD50 0x14

#define BXRolandSysexDeviceIDDefault 0x10

#define BXRolandSysexRequest 0x11
#define BXRolandSysexSend 0x12

#define BXRolandSysexSendMinLength BXRolandSysexHeaderLength + BXRolandSysexAddressLength + BXRolandSysexTailLength

#define BXRolandSysexRequestLength BXRolandSysexHeaderLength + BXRolandSysexAddressLength + BXRolandSysexRequestSizeLength + BXRolandSysexTailLength

#pragma mark -
#pragma mark MT-32-specific sysex message parameters

#define BXMT32LCDMessageLength 20
#define BXMT32SysexAddressPatchMemory 0x05
#define BXMT32SysexAddressTimbreMemory 0x08
#define BXMT32SysexAddressSystemArea 0x10
#define BXMT32SysexAddressReset 0x7F
#define BXMT32SysexAddressDisplay 0x20

#define BXMT32SysexSubAddressMasterVolume 0x16


#define BXChannelModeChangePrefix 0xB0
#define BXAllNotesOffMessage 0x7B