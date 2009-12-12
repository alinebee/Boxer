/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXStatusBar.h"

//Interface Builder tags
enum {
	BXStatusBarLockButton	= 1,
	BXStatusBarSpeedLabel	= 2,
	BXStatusBarSpeedSlider	= 3,
	BXStatusBarTortoise		= 4,
	BXStatusBarBunny		= 5
};

//Resize strategy to make sure no status items overlap
@implementation BXStatusBar
- (void) awakeFromNib
{
	//Force bevelled appearance for our items
	id speedLabel = [self viewWithTag: BXStatusBarSpeedLabel];
	[[speedLabel cell] setBackgroundStyle: NSBackgroundStyleRaised];
}

- (void)resizeWithOldSuperviewSize: (NSSize)oldBoundsSize
{
	[super resizeWithOldSuperviewSize: oldBoundsSize];
	
	NSArray *subviews = [self subviews];
	
	id lockButton = [self viewWithTag: BXStatusBarLockButton];
	for (id subview in subviews)
	{
		if (lockButton != subview)
			[subview setHidden: NSIntersectsRect([subview frame], [lockButton frame])];
	}
}
@end

//Used by the mouselock button to handle its peculiar state requirements (alternate image shown when button is pressed in, but alternate title only shown when button is in the on state)

@implementation BXToggleButtonCell
- (NSAttributedString *) attributedAlternateTitle
{
	if ([self state]) return [super attributedAlternateTitle];
	else return [super attributedTitle];
}
- (NSAttributedString *) attributedTitle
{
	if (![self state] || ![super attributedAlternateTitle]) return [super attributedTitle];
	else return [super attributedAlternateTitle];
}
@end