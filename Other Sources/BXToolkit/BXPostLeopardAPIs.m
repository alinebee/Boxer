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
    Class proxiedClass = [NSFileManager class];
    
    //Implementation for createDirectoryAtURL:withIntermediateDirectories:attributes:error:
    SEL createDir = @selector(createDirectoryAtURL:withIntermediateDirectories:attributes:error:);
    [self addInstanceMethod: createDir toClass: proxiedClass];
    
    SEL createSymlink = @selector(createSymbolicLinkAtURL:withDestinationURL:error:);
    [self addInstanceMethod: createSymlink toClass: proxiedClass];
    
    SEL trashItem = @selector(trashItemAtURL:resultingItemURL:error:);
    [self addInstanceMethod: trashItem toClass: proxiedClass];
}

- (BOOL) createDirectoryAtURL: (NSURL *)URL
  withIntermediateDirectories: (BOOL)createIntermediates
                   attributes: (NSDictionary *)attributes
                        error: (out NSError **)error
{
    return [(NSFileManager *)self createDirectoryAtPath: URL.path
                            withIntermediateDirectories: createIntermediates
                                             attributes: attributes
                                                  error: error];
}

- (BOOL) createSymbolicLinkAtURL: (NSURL *)URL
              withDestinationURL: (NSURL *)destURL
                           error: (out NSError **)error
{
    return [(NSFileManager *)self createSymbolicLinkAtPath: URL.path
                                       withDestinationPath: destURL.path
                                                     error: error];
    
}

- (BOOL) trashItemAtURL: (NSURL *)url resultingItemURL: (out NSURL **)outResultingURL error: (out NSError **)outError
{
    const char *originalPath = [(NSFileManager *)self fileSystemRepresentationWithPath: url.path];
    char *trashedPath = NULL;
    
    OSStatus result = FSPathMoveObjectToTrashSync(originalPath, (outResultingURL ? &trashedPath : NULL), kFSFileOperationDefaultOptions);
    if (result == noErr)
    {
        if (outResultingURL && trashedPath)
        {
            NSString *path = [(NSFileManager *)self stringWithFileSystemRepresentation: trashedPath length: strlen(trashedPath)];
            *outResultingURL = [NSURL fileURLWithPath: path];
            free(trashedPath);
        }
        return YES;
    }
    else
    {
        if (outError)
            *outError = [NSError errorWithDomain: NSOSStatusErrorDomain code: result userInfo: @{ NSURLErrorKey: url }];
        
        return NO;
    }
}
@end