/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXCollectionItemView and BXCollectionItem implement baseline behaviours to make working with
//NSCollectionViews a less miserable experience.

#import <Cocoa/Cocoa.h>

/// Designed for use with BXCollectionItemView: runs viewDidLoad for every item created,
/// and tells its view to redraw whenever the item's selected status changes.
@interface BXCollectionItem : NSCollectionViewItem

/// Called for every collection view item after the view has been set or the item has been cloned.
///
/// Intended to be overridden in subclasses to perform additional initialization.
- (void) viewDidLoad;

@end


@interface BXCollectionItemView : NSView
{
	__unsafe_unretained NSCollectionViewItem *_delegate;
}
/// A nonretained reference back to the collection view item we represent.
@property (assign, nonatomic) IBOutlet NSCollectionViewItem *delegate;

/// The view prototype we were copied from.
@property (weak, readonly, nonatomic) NSView *prototype;

/// Called by BXCollectionItem when the item's selected status changes.
/// By default, flags the view as needing to be displayed.
- (void) collectionViewItemDidChangeSelection;
@end


/// Provides a blue lozenge appearance when its collection view item is selected.
@interface BXHUDCollectionItemView : BXCollectionItemView
@end



@interface BXInspectorListCollectionItemView : BXCollectionItemView
@end
