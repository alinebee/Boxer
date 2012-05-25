/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFrameRateCounterLayer.h"

@implementation BXFrameRateCounterLayer
@synthesize frameRate;

- (void) setFrameRate: (CGFloat)newRate
{
	frameRate = newRate;	
	[self setString: [NSString stringWithFormat: @"%0.02f fps", newRate]];
}

@end
