/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXProgramPanel defines minor NSView subclasses to customise the appearance and behaviour of
//program picker panel views.

#import <Cocoa/Cocoa.h>
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


//BXProgramItemButton is used for the buttons in the program chooser panel. Each
//button tracks its relevant collection item as a delegate, to make it possible to
//customise the button's appearance based on the program it represents.
@interface BXProgramItemButton : NSButton
{
	IBOutlet NSCollectionViewItem *delegate;
}
//A reference to the collection item defining which program we are representing.
@property (assign) NSCollectionViewItem *delegate;

//A reference to the dictionary represented by our collection item delegate.
- (id) representedObject;

@end
