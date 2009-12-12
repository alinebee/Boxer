/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXProgramPanelController manages the program picker panel inside the session window. It is
//responsible for populating the program selection and toggling which picker interface is shown
//(picker, default program toggle, no programs notice) based on the state of the emulator session.

#import <Cocoa/Cocoa.h>

@class BXSessionWindowController;
@class BXSession;

@interface BXProgramPanelController : NSViewController
{
	IBOutlet BXSessionWindowController *controller;
	IBOutlet NSView *programList;
	IBOutlet NSView *defaultTargetToggle;
	IBOutlet NSView *noProgramsNotice;
}
@property (retain) NSView *programList;				//The program picker view.
@property (retain) NSView *defaultTargetToggle;		//The default program toggle view.
@property (retain) NSView *noProgramsNotice;		//The no-programs-found notice view.
@property (assign) BXSessionWindowController *controller;	//The controller we are responsible to.

//Returns the session to which this program panel belongs (i.e., the BXSessionWindowController's document)
- (BXSession *) session;

//Returns the localised display string used for the "open this program every time" checkbox toggle.
- (NSString *) labelForToggle;

//Opens the path of the sender's represented object, called by our program picker buttons.
//TODO: this duplicates the behaviour of BXFileManager's openInDOS: action. Look into
//linking our picker buttons directly to that instead.
- (IBAction) openFileInDOS:	(id)sender;

//Set/get whether the session's currently executing program is the default program for its gamebox.
//Used by the default program toggle view.
- (BOOL) activeProgramIsDefault;
- (void) setActiveProgramIsDefault: (BOOL) isDefault;

@end