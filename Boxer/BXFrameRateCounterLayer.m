/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFrameRateCounterLayer.h"

@implementation BXFrameRateCounterLayer
@synthesize frameRate;

- (void) setFrameRate: (CGFloat)newRate
{
	[self willChangeValueForKey: @"frameRate"];
	frameRate = newRate;
	[self didChangeValueForKey: @"frameRate"];
	
	[self setString: [NSString stringWithFormat: @"%0.02f fps", newRate, nil]];
}
@end