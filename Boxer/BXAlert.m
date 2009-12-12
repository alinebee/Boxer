/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXAlert.h"
#import "BXSession.h"

@implementation BXAlert
+ (id) alert	{ return [[[self alloc] init] autorelease]; }

- (BOOL) adoptIconFromWindow: (NSWindow *)window
{
	id document = [[window windowController] document];
	if ([document isKindOfClass: [BXSession class]])
	{
		NSImage *sessionIcon = [document representedIcon];
		if (sessionIcon)
		{
			[self setIcon: sessionIcon];
			return YES;
		}
	}
	return NO;
}

//Shortcut that automatically assigns our class's callback selector
- (void) beginSheetModalForWindow: (NSWindow *)window contextInfo: (void *)contextInfo
{
	[self adoptIconFromWindow: window];
	[self retain];	//The alert will be released in the callback function below
	[self beginSheetModalForWindow:	window
					modalDelegate:	[self class]
					didEndSelector:	@selector(alertDidEnd:returnCode:contextInfo:)
					contextInfo:	contextInfo];
}

//Basic implementation which does nothing but clean up
+ (void) alertDidEnd: (BXAlert *)alert returnCode: (int)returnCode contextInfo: (void *)contextInfo
{
	[alert release];
}
@end
