/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXCoalfaceDrives defines C++-facing Boxer hooks that are specific
//to DOSBox's drive framework and unsuitable for general inclusion.

#import "BXCoalface.h"
#import "drives.h"


//Byte-swapping to fix endianness issues on PowerPC
//when reading/writing header structs from FAT images.
bootstrap boxer_FATBootstrapLittleToHost(bootstrap bootstrap);
bootstrap boxer_FATBootstrapHostToLittle(bootstrap bootstrap);

direntry boxer_FATDirEntryLittleToHost(direntry entry);
direntry boxer_FATDirEntryHostToLittle(direntry entry);

partTable boxer_FATPartitionTableLittleToHost(partTable table);
partTable boxer_FATPartitionTableHostToLittle(partTable table);
