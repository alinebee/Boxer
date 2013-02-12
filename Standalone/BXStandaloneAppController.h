/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXStandaloneAppController is a variant of the basic app controller,
//suitable for standalone app-bundles of games. It eliminates large swathes
//of unnecessary functionality found in the standard app controller.

#import "BXBaseAppController.h"

@interface BXStandaloneAppController : BXBaseAppController

//The name of the organization producing the standalone app bundles.
+ (NSString *)organizationName;

//Launches the gamebox bundled in the application and returns the resulting session.
//Returns nil and populates outError if the bundled gamebox could not be launched.
- (id) openBundledGameAndDisplay: (BOOL)display error: (NSError **)outError;

//Custom menu actions for standalone games.
- (IBAction) visitOrganizationWebsite: (id)sender;

@end
