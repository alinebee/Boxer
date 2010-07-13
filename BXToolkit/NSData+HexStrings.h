/* 
 This code was found online in a comment at:
 http://notes.stripsapp.com/nsdata-to-nsstring-as-hex-bytes/
 Its original authorship is unknown but to the best of my knowledge,
 the code was provided with no explicit copyright or license.
 */


#import <Foundation/Foundation.h>

@interface NSData (HexStrings)

//Returns a hexadecimal version of the NSData object.
//(Similar to the output of description, but without some cruft.)
- (NSString *) stringWithHexBytes;

@end
