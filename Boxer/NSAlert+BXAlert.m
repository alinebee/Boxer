/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "NSAlert+BXAlert.h"

@implementation NSAlert (BXAlert)
+ (id) alert	{ return [[[self alloc] init] autorelease]; }

- (BOOL) adoptIconFromWindow: (NSWindow *)window
{
	NSImage *icon = [[window standardWindowButton: NSWindowDocumentIconButton] image];
 
	if (icon)
	{
		//Copy the icon so we can modify the size without affecting the original
		icon = [icon copy];
		[icon setSize: NSMakeSize(128, 128)];
		[self setIcon: icon];
		[icon release];
		return YES;
	}
	return NO;
}
@end
