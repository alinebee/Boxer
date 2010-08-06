/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXPreferencesController manages Boxer's application preferences panel.

#import <Cocoa/Cocoa.h>

@class BXFilterGallery;

@interface BXPreferencesController : NSWindowController
{
	//An outlet for the filter gallery we are managing
	IBOutlet BXFilterGallery *filterGallery;
}

//Provides a singleton instance of the window controller which stays retained for the lifetime
//of the application. BXPreferencesController should always be accessed from this singleton.
+ (BXPreferencesController *) controller;

//Change the default render filter to match the sender's tag.
//Note that this uses an intentionally different name from the toggleFilterType: defined on
//BXDOSWindowController and used by main menu items, as the two sets of controls need to be
//validated differently.
- (IBAction) toggleDefaultFilterType: (id)sender;

//Synchonises the filter gallery controls to the current default filter.
//This is called through Key-Value Observing whenever the filter preference changes.
- (void) syncFilterControls;

@end
