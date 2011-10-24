/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXProgramPanel defines minor NSView subclasses to customise the appearance and behaviour of
//program picker panel views.

#import <Cocoa/Cocoa.h>
#import "BXCollectionItemView.h"
#import "BXThemedControls.h"
#import "YRKSpinningProgressIndicator.h"

//Interface Builder tags
enum {
	BXProgramPanelTitle			= 1,
	BXProgramPanelDefaultToggle	= 2,
	BXProgramPanelHide			= 3,
	BXProgramPanelButtons		= 4
};

//BXProgramPanel is the containing view for all other panel content. This class draws
//itself as a shaded grey gradient background with a grille at the top.
@interface BXProgramPanel : NSView
@end

//The tracking item for individual programs in the program panel collection view.
@interface BXProgramItem : BXCollectionItem
{
    NSButton *programButton;
}
@property (retain, nonatomic) NSButton *programButton;
@end

//Custom button appearance for buttons in the program panel collection view.
@interface BXProgramItemButtonCell : BXThemedButtonCell
{
    BOOL mouseIsInside;
    BOOL programIsDefault;
}
@property (assign, nonatomic) BOOL programIsDefault;
@property (assign, nonatomic) BOOL mouseIsInside;
@end


//A subclass to fix some hugely annoying redraw bugs
//in 10.5's implementation of NSCollectionView
@interface BXProgramListView : NSCollectionView
{
    @private
    NSArray *_pendingContent;
}
@end