/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXScriptedPreferences.h"
#import "BXPreferencesController.h"
#import "BXScriptedWindow.h"

@implementation BXScriptedPreferences

- (NSWindow *)window
{
	NSWindow *window = [[BXPreferencesController controller] window];
	return [BXScriptedWindow scriptedWindow: window];
}

+ (BXScriptedPreferences *) sharedPreferences
{
	BXScriptedPreferences *preferences = nil;
	if (!preferences) preferences = [[self alloc] init];
	return preferences;
}

- (NSScriptObjectSpecifier *) objectSpecifier
{
	NSScriptClassDescription *appDesc = [NSScriptClassDescription classDescriptionForClass: [NSApplication class]];
	
	NSScriptObjectSpecifier *specifier = [[NSPropertySpecifier alloc] initWithContainerClassDescription: appDesc
																					 containerSpecifier: nil
																									key: @"Boxer preferences"];
	
	return [specifier autorelease];
}
@end
