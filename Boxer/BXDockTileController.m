/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */



#import "BXDockTileController.h"
#import "BXBaseAppController.h"
#import "BXSession.h"

@implementation BXDockTileController

- (void) awakeFromNib
{
	//Listen for changes to the current session's represented icon
	[(BXBaseAppController *)[NSApp delegate] addObserver: self
                                              forKeyPath: @"currentSession.representedIcon"
                                                 options: NSKeyValueObservingOptionInitial
                                                 context: nil];
}

- (void) dealloc
{
	[(BXBaseAppController *)[NSApp delegate] removeObserver: self forKeyPath: @"currentSession.representedIcon"];
	[super dealloc];
}

//Whenever the represented icon changes, force a redraw of our icon view
- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{	
	if ([keyPath isEqualToString: @"currentSession.representedIcon"])
        [self syncIconWithActiveSession];
}

- (void) syncIconWithActiveSession
{
	BXSession *session = [(BXBaseAppController *)[NSApp delegate] currentSession];
	NSImage *icon = [[session.representedIcon copy] autorelease];
    
    //If the session didn't have an icon of its own, generate a bootleg one
    //based on the size and age of the files in the gamebox.
	if (icon)
	{
        icon.size = NSMakeSize(128, 128);
        [NSApp setApplicationIconImage: icon];
	}
	else [NSApp setApplicationIconImage: nil];
}
@end
