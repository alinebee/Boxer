/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportFinalizingPanelController manages the finalizing-gamebox view of the game import window.

#import <Cocoa/Cocoa.h>
#import "BXImportSession.h"

@class BXImportWindowController;
@interface BXImportFinalizingPanelController : NSViewController
{
	IBOutlet BXImportWindowController *controller;
}

#pragma mark -
#pragma mark Properties

//A reference to our window controller.
@property (assign, nonatomic) BXImportWindowController *controller;

//A textual description of what import stage we are currently performing.
//Used for populating the description field beneath the progress bar.
@property (readonly, nonatomic) NSString *progressDescription;

//Text and visibility properties for the skip-importing-source-files button.
@property (readonly, nonatomic) NSString * skipButtonLabel;
@property (readonly, nonatomic) BOOL showSkipButton;
@property (readonly, nonatomic) BOOL enableSkipButton;


#pragma mark -
#pragma mark Helper class methods

//Helper methods used by progressDescription and skipButtonLabel.
+ (NSString *) skipButtonLabelForImportType: (BXSourceFileImportType)importType;
+ (NSString *) stageDescriptionForImportType: (BXSourceFileImportType)importType;

+ (NSAlert *) skipAlertForSourcePath: (NSString *)sourcePath
								type: (BXSourceFileImportType)importType;


#pragma mark -
#pragma mark UI actions

//Display help for this stage of the import process.
- (IBAction) showImportFinalizingHelp: (id)sender;

//Skip the source file import stage. This will show a confirmation prompt.
- (IBAction) skipSourceFileImport: (id)sender;

@end