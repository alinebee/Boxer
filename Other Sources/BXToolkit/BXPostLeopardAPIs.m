/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXPostLeopardAPIs.h"
#import <objc/runtime.h>

NSString * const NSWindowDidChangeBackingPropertiesNotification = @"NSWindowDidChangeBackingPropertiesNotification";
NSString * const NSWindowWillEnterFullScreenNotification = @"NSWindowWillEnterFullScreenNotification";
NSString * const NSWindowDidEnterFullScreenNotification = @"NSWindowDidEnterFullScreenNotification";
NSString * const NSWindowWillExitFullScreenNotification = @"NSWindowWillExitFullScreenNotification";
NSString * const NSWindowDidExitFullScreenNotification = @"NSWindowDidExitFullScreenNotification";


@implementation BXFallbackProxyCategory

+ (void) addInstanceMethod: (SEL)selector toClass: (Class)targetClass
{
    //Don't bother if the class already implements this selector.
    if ([targetClass instancesRespondToSelector: selector])
        return;
    
    NSAssert2([self instancesRespondToSelector: selector], @"Selector not implemented on %@: %@", self, NSStringFromSelector(selector));
    
    Method method = class_getInstanceMethod(self, selector);
    IMP implementation = method_getImplementation(method);
    const char *types = method_getTypeEncoding(method);
    
    class_addMethod(targetClass, selector, implementation, types);
}

@end

@implementation NSFileManagerProxyCategory

+ (void) load
{
    //Implementation for createDirectoryAtURL:withIntermediateDirectories:attributes:error:
    SEL selector = @selector(createDirectoryAtURL:withIntermediateDirectories:attributes:error:);
    [self addInstanceMethod: selector toClass: [NSFileManager class]];
}

- (BOOL) createDirectoryAtURL: (NSURL *)URL
  withIntermediateDirectories: (BOOL)createIntermediates
                   attributes: (NSDictionary *)attributes
                        error: (NSError **)error
{
    return [(NSFileManager *)self createDirectoryAtPath: URL.path
                            withIntermediateDirectories: createIntermediates
                                             attributes: attributes
                                                  error: error];
}

@end