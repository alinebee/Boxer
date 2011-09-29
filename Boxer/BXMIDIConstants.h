/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//MIDI-related constants for General MIDI and MT-32 messages.

#define BXSysexStart 0xF0
#define BXSysexEnd 0xF7

#define BXSysexManufacturerIDRoland 0x41
#define BXSysexManufacturerIDNonRealtime 0x7E
#define BXSysexManufacturerIDRealtime 0x7F

#define BXRolandSysexModelIDMT32 0x16
#define BXRolandSysexModelIDD50 0x14

#define BXRolandSysexDeviceIDDefault 0x10

#define BXRolandSysexDataRequest 0x11
#define BXRolandSysexDataSend 0x12

#define BXRolandSysexAddressPatchMemory 0x05
#define BXRolandSysexAddressTimbreMemory 0x08
#define BXRolandSysexAddressSystemArea 0x10
#define BXRolandSysexAddressReset 0x7F
#define BXRolandSysexAddressDisplay 0x20



#define BXChannelModeChangePrefix 0xB0
#define BXAllNotesOffMessage 0x7B