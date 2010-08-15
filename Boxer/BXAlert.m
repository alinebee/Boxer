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
		else
		{
			[self setIcon: [NSApp applicationIconImage]];
			return YES;
		}
	}
	return NO;
}
@end
