/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXPostLeopardAPIs.h"


#if MAC_OS_X_VERSION_MAX_ALLOWED < 1070 //OS X 10.7

NSString * const NSWindowDidChangeBackingPropertiesNotification = @"NSWindowDidChangeBackingPropertiesNotification";
NSString * const NSWindowWillEnterFullScreenNotification = @"NSWindowWillEnterFullScreenNotification";
NSString * const NSWindowDidEnterFullScreenNotification = @"NSWindowDidEnterFullScreenNotification";
NSString * const NSWindowWillExitFullScreenNotification = @"NSWindowWillExitFullScreenNotification";
NSString * const NSWindowDidExitFullScreenNotification = @"NSWindowDidExitFullScreenNotification";


@implementation NSFileManager (BXPostLeopardFileManagerAPIs)

- (BOOL) createDirectoryAtURL: (NSURL *)URL
  withIntermediateDirectories: (BOOL)createIntermediates
                   attributes: (NSDictionary *)attributes
                        error: (NSError **)error
{
    return [self createDirectoryAtPath: URL.path
           withIntermediateDirectories: createIntermediates
                            attributes: attributes
                                 error: error];
}

@end

#endif