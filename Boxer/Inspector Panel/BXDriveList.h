/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>
#import "BXCollectionItemView.h"
#import "BXThemedButtonCell.h"

@class BXDrive;
@class BXDriveItem;
@class BXDriveItemView;

/// \c BXDriveList represents the currently-mounted DOS drives in the Boxer inspector panel. It is
/// a custom subclass of the standard Cocoa collection view to implement drag operations for drives.
@interface BXDriveList : NSCollectionView

/// Returns the collection view item representing the specified drive.
- (BXDriveItem *) itemForDrive: (BXDrive *)drive;

@end


/// BXDriveItemView displays each drive entry in the list.
@interface BXDriveItemView : BXInspectorListCollectionItemView
@end


/// A custom appearance for control buttons within drive item views.
@interface BXDriveItemButtonCell : BXThemedButtonCell
{
	BOOL _hovered;
}
@property (assign, nonatomic, getter=isHovered) BOOL hovered;
@end


/// A custom appearance for drive labels.
@interface BXDriveLetterCell : NSTextFieldCell <BXThemable>
{
    NSString *_themeKey;
}
@end
