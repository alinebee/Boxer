/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportPanel and friends are NSView subclasses to define the custom appearance and behaviour
//of import panel UI items.


#import <Cocoa/Cocoa.h>

//The background view of a panel in the import window. Drawn with a blueprint appearance.
@interface BXImportPanel : NSView
@end


//A modified version of the above for use in the program-chooser panel of DOS windows.
//Uses a different gradient and layout.
@interface BXImportProgramPanel : BXImportPanel
@end
