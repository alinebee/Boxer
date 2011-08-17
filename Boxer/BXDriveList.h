/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDriveList represents the currently-mounted DOS drives in the Boxer inspector panel. It is
//a custom subclass of the standard Cocoa collection view to implement drag operations for drives.

#import <Cocoa/Cocoa.h>
#import "BXCollectionItemView.h"

@class BXDrive;
@class BXDriveItemView;
@class BXDrivePanelController;

@interface BXDriveList : NSCollectionView
{
	IBOutlet BXDrivePanelController *delegate;
}
@property (assign, nonatomic) BXDrivePanelController *delegate;

//An array of BXDriveItemViews corresponding to the current selection.
@property (readonly, nonatomic) NSArray *selectedViews;

//Returns the view that represents the specified drive.
- (BXDriveItemView *) viewForDrive: (BXDrive *)drive;

@end


//BXDriveItemView wraps each drive icon in the list.
@interface BXDriveItemView : BXHUDCollectionItemView

@property (readonly, nonatomic) NSTextField *driveTypeLabel;
@property (readonly, nonatomic) NSTextField *displayNameLabel;
@property (readonly, nonatomic) NSTextField *letterLabel;
@property (readonly, nonatomic) NSTextField *progressMeterLabel;
@property (readonly, nonatomic) NSImageView *driveIcon;
@property (readonly, nonatomic) NSProgressIndicator *progressMeter;
@property (readonly, nonatomic) NSButton *progressMeterCancel;

@end


//A custom appearance for control buttons within drive item views.
@interface BXDriveItemButtonCell : NSButtonCell
{
	BOOL hovered;
}
@property (assign, getter=isHovered) BOOL hovered;
@end
