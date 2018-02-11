/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportFinalizingPanelController manages the finalizing-gamebox view of the game import window.

#import <Cocoa/Cocoa.h>
#import "BXImportSession.h"

@class BXImportWindowController;
@interface BXImportFinalizingPanelController : NSViewController
{
    __unsafe_unretained BXImportWindowController *_controller;
}

#pragma mark -
#pragma mark Properties

//A reference to our window controller.
@property (assign, nonatomic) IBOutlet BXImportWindowController *controller;

//A textual description of what import stage we are currently performing.
//Used for populating the description field beneath the progress bar.
@property (copy, readonly, nonatomic) NSString *progressDescription;

//The label and enabledness of the stop importing/skip importing button.
@property (copy, readonly, nonatomic) NSString * cancelButtonLabel;
@property (readonly, nonatomic) BOOL cancelButtonEnabled;

//Whether to show the tip about importing additional CDs.
//Will be YES if the source is a CD-ROM or CD image, NO otherwise.
@property (readonly, nonatomic) BOOL showAdditionalCDTips;


#pragma mark -
#pragma mark Helper class methods

//Helper methods used by progressDescription and cancelButtonLabel.
+ (NSString *) cancelButtonLabelForImportType: (BXSourceFileImportType)importType;
+ (NSString *) stageDescriptionForImportType: (BXSourceFileImportType)importType;

+ (NSAlert *) skipAlertForSourceURL: (NSURL *)sourceURL
                               type: (BXSourceFileImportType)importType;


#pragma mark -
#pragma mark UI actions

//Display help for this stage of the import process.
- (IBAction) showImportFinalizingHelp: (id)sender;

//Skip the source file import stage. This will show a confirmation prompt.
- (IBAction) cancelSourceFileImport: (id)sender;

@end
