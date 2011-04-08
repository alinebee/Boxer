/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXBinCueImageImport rips CD-ROM discs to BIN/CUE images that are bundled into a .cdmedia bundle.

#import "BXCDImageImport.h"

@interface BXBinCueImageImport : BXCDImageImport
{	
	@protected
	NSFileManager *manager;
}
@end
