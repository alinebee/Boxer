/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXFrameRateCounterLayer is a cheap and dirty subclass of CATextLayer to format a provided/bound
//frame rate as a suitable string for display.

#import <QuartzCore/QuartzCore.h>

@interface BXFrameRateCounterLayer : CATextLayer
{
	CGFloat frameRate;
}
@property (assign) CGFloat frameRate;
@end