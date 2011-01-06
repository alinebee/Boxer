/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXLineEnumerator allows easy enumeration of the lines of an NSString.
//It is exposed as a method on NSString by the BXWordWrap category, but can be used separately also.

#import <Foundation/Foundation.h>

@interface BXLineEnumerator : NSEnumerator
{
	NSUInteger lineStart;
	NSUInteger contentsEnd;
	NSUInteger lineEnd;
	NSUInteger length;
	NSString *enumeratedString;
}

//Create a new line enumerator for the specified string.
- (id) initWithString: (NSString *)theString;

//BXLineEnumerator always returns strings.
- (NSString *) nextObject;

@end