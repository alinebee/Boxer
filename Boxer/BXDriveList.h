/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDriveList represents the currently-mounted DOS drives in the Boxer inspector panel. It is
//a custom subclass of the standard Cocoa collection view to implement drag operations for drives.

#import <Cocoa/Cocoa.h>

@class BXDrivePanelController;

@interface BXDriveList : NSCollectionView
{
	IBOutlet BXDrivePanelController *delegate;
}
@property (assign) BXDrivePanelController *delegate;

- (NSArray *) selectedObjects;	//An array of the currently selected NSCollectionViewItems.
- (NSArray *) selectedViews;	//An array of BXDriveItemViews corresponding to the currently selected drives.

@end


//BXDriveItemView wraps each drive icon in the list. It exposes its collection view item as a delegate,
//so that its child views can bind to the item and respond to its state appropriately.
@interface BXDriveItemView : NSView
{
	IBOutlet NSCollectionViewItem *delegate;
}
//A nonretained reference to the item defining which drive we are representing.
@property (assign) NSCollectionViewItem *delegate;

@end
