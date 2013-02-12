/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXCloseAlert defines close-this-window confirmation alert sheets for various contexts.

#import <Cocoa/Cocoa.h>

@class BXSession;
@class BXImportSession;

@interface BXCloseAlert : NSAlert

//Shown when closing the window while a DOSBox process is running.
//Warns the user that any unsaved data will be lost if they continue.
+ (BXCloseAlert *) closeAlertWhileSessionIsEmulating: (BXSession *)theSession;

//Shown when closing the window while one or more drive import operations are in progress.
+ (BXCloseAlert *) closeAlertWhileImportingDrives: (BXSession *)theSession;

//Shown when closing the window while a game import is in progress.
+ (BXCloseAlert *) closeAlertWhileImportingGame: (BXImportSession *)theSession;

//Shown when closing the window while a game installer is running during import.
+ (BXCloseAlert *) closeAlertWhileRunningInstaller: (BXImportSession *)theSession;

//Shown after a windows-only program has failed to run and exited.
+ (BXCloseAlert *) closeAlertAfterWindowsOnlyProgramExited: (NSString *)programPath;

//Shown when returning to the launch panel while a DOSBox process is running.
//Warns the user that any unsaved data will be lost if they continue.
+ (BXCloseAlert *) restartAlertWhenReturningToLaunchPanel: (BXSession *)theSession;

//Shown when restarting the session while a DOSBox process is running.
//Warns the user that any unsaved data will be lost if they continue.
+ (BXCloseAlert *) restartAlertWhileSessionIsEmulating: (BXSession *)theSession;

//Shown when restarting the session while one or more drive import operations are in progress.
+ (BXCloseAlert *) restartAlertWhileImportingDrives: (BXSession *)theSession;

@end
