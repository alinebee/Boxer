/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXWordWrap category adds methods for hard-wrapping NSStrings to a specified column width
//for writing text files.

#import <Foundation/Foundation.h>

@interface NSString (BXWordWrap)

//Returns an array of lines split at the specified line length.
//If wordWrap is YES, the substrings will be split at the nearest whitespace (unless an entire
//word fills the line); otherwise they will be split willy-nilly in the middle of words.
- (NSArray *) componentsSplitAtLineLength: (NSUInteger)lineLength atWordBoundaries: (BOOL)wordWrap;

//Return strings word/character-wrapped to the specified line length, with the specified string joining each line.
- (NSString *) stringWordWrappedAtLineLength: (NSUInteger)lineLength withJoiner: (NSString *)joiner;
- (NSString *) stringCharacterWrappedAtLineLength: (NSUInteger)lineLength withJoiner: (NSString *)joiner;

@end
