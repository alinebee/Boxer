/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

@class BXSession;
@class BXImportSession;

/// \c BXCloseAlert defines close-this-window confirmation alert sheets for various contexts.
@interface BXCloseAlert : NSAlert

/// Shown when closing the window while a DOSBox process is running.
///
/// Warns the user that any unsaved data will be lost if they continue.
+ (instancetype) closeAlertWhileSessionIsEmulating: (BXSession *)theSession;

/// Shown when closing the window while one or more drive import operations are in progress.
+ (instancetype) closeAlertWhileImportingDrives: (BXSession *)theSession;

/// Shown when closing the window while a game import is in progress.
+ (instancetype) closeAlertWhileImportingGame: (BXImportSession *)theSession;

/// Shown when closing the window while a game installer is running during import.
+ (instancetype) closeAlertWhileRunningInstaller: (BXImportSession *)theSession;

/// Shown after a windows-only program has failed to run and exited.
+ (instancetype) closeAlertAfterWindowsOnlyProgramExited: (NSString *)programPath;

///Shown when returning to the launch panel while a DOSBox process is running.
///
/// Warns the user that any unsaved data will be lost if they continue.
+ (instancetype) restartAlertWhenReturningToLaunchPanel: (BXSession *)theSession;

/// Shown when restarting the session while a DOSBox process is running.
///
/// Warns the user that any unsaved data will be lost if they continue.
+ (instancetype) restartAlertWhileSessionIsEmulating: (BXSession *)theSession;

/// Shown when restarting the session while one or more drive import operations are in progress.
+ (instancetype) restartAlertWhileImportingDrives: (BXSession *)theSession;

@end
