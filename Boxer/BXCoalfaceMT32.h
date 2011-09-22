/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXCoalfaceMT32 defines C++-facing Boxer hooks for MUNT MT-32 emulation.
//These (mostly) pass the decision-making upstairs to the BXEmulator+BXAudio category.

#import "BXCoalface.h"
#import "MT32Emu/mt32emu.h"


//Callback for loading ROM files.
MT32Emu::File *boxer_openMT32ROM(void *userData, const char *filename);

//Callback for closing ROM files.
void boxer_closeMT32ROM(void *userData, MT32Emu::File *file);

//Callback for reporting various messages from the MT-32 emulator.
int boxer_reportMT32Message(void *userData, MT32Emu::ReportType type, const void *reportData);

//Callback for debug/error messages from the MT-32 emulator.
void boxer_logMT32DebugMessage(void *userData, const char *fmt, va_list list);

//Convert a 4-byte array to a 32-bit integer for MT32Emu::Synth->playMsg calls,
//maintaining the expected endianness.
Bit32u boxer_MIDIMessageToLong(Bit8u *msg);

