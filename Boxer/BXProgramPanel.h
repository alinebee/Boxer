/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXProgramPanel defines minor NSView subclasses to customise the appearance and behaviour of
//program picker panel views.

#import <Cocoa/Cocoa.h>

//BXProgramPanel is the containing view for all other panel content. This class draws
//itself as a shaded grey gradient background with a grille at the top.
@interface BXProgramPanel : NSView
@end


//BXProgramItemView wraps each program button in the picker. This class aligns itself
//inside its parent NSCollectionView according to how many other siblings it has.
//It also exposes its collection view item as a delegate, so that its descendant views
//can bind to the item and respond to its state appropriately.
@interface BXProgramItemView : NSView
{
	IBOutlet NSCollectionViewItem *delegate;
}
//A nonretained reference to the item defining which program we are representing.
@property (assign) NSCollectionViewItem *delegate;

//A shortcut accessor for our first (and only) child view.
- (id) contents;

//Relatively align our fixed-width child view within our flexible-width bounds.
//0.0 is left, 1.0 is right, 0.5 is centered.
- (void) alignContentsToPosition: (CGFloat)position;
@end


//Assigned to program picker buttons in the NIB file, but currently does nothing.
//Kept around for now in case we want to customise the appearance or behaviour of them.
@interface BXProgramButton : NSButton
@end
