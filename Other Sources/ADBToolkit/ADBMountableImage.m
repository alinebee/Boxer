/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */

#import "ADBMountableImage.h"
#import "ADBLocalFilesystemPrivate.h"
#import "NSWorkspace+ADBMountedVolumes.h"
#import "NSURL+ADBFilesystemHelpers.h"

NSString * const ADBMountableImageErrorDomain = @"ADBMountableImageErrorDomain";

@interface ADBMountableImage ()

//A cached record of the OS X filesystem location at which the image is mounted.
//This is populated automatically by volumeURLMountingIfNeeded:error:, and will
//be cleared automatically if the filesystem detects that the image has been unmounted.
@property (copy, nonatomic) NSURL *mountedVolumeURL;

@end

@implementation ADBMountableImage

@synthesize unmountWhenDone = _unmountWhenDone;
@synthesize mountedVolumeURL = _mountedVolumeURL;

+ (NSSet *) supportedImageTypes
{
    static NSSet *imageTypes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        imageTypes = [[NSSet alloc] initWithObjects:
                      @"public.iso-image",                      //.iso
                      @"com.apple.disk-image-cdr",              //.cdr
                      @"com.winimage.raw-disk-image",           //.ima
                      @"com.apple.disk-image-ndif",             //.img
                      @"com.microsoft.virtualpc-disk-image",    //.vfd
                      nil];
    });
    return imageTypes;
}

+ (id) imageWithContentsOfURL: (NSURL *)baseURL error: (out NSError **)outError
{
    return [[(ADBMountableImage *)[self alloc] initWithContentsOfURL: baseURL error: outError] autorelease];
}

- (id) initWithContentsOfURL: (NSURL *)baseURL error: (out NSError **)outError
{
    if ([baseURL matchingFileType: [self.class supportedImageTypes]])
    {
        self = [self initWithBaseURL: baseURL];
    }
    else
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: ADBMountableImageErrorDomain
                                            code: ADBMountableImageUnsupportedImageType
                                        userInfo: @{ NSURLErrorKey: baseURL }];
        }
        
        [self release];
        self = nil;
    }
    return self;
}

- (id) init
{
    self = [super init];
    if (self)
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        NSNotificationCenter *wsCenter = [NSWorkspace sharedWorkspace].notificationCenter;
        
        [center addObserver: self
                   selector: @selector(applicationWillTerminate:)
                       name: NSApplicationWillTerminateNotification
                     object: nil];
        
        [wsCenter addObserver: self
                     selector: @selector(volumeDidUnmount:)
                         name: NSWorkspaceDidUnmountNotification
                       object: nil];
        
        [wsCenter addObserver: self
                     selector: @selector(volumeDidRename:)
                         name: NSWorkspaceDidRenameVolumeNotification
                       object: nil];
        
        
    }
    return self;
}

- (void) dealloc
{
    [[NSWorkspace sharedWorkspace].notificationCenter removeObserver: self];
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    
    if (self.unmountWhenDone && self.mountedVolumeURL)
        [self unmountVolumeWithError: NULL];
    
    self.mountedVolumeURL = nil;
    [super dealloc];
}


#pragma mark - Mounting and unmounting

- (void) applicationWillTerminate: (NSNotification *)notification
{
    if (self.unmountWhenDone && self.mountedVolumeURL)
    {
        [self unmountVolumeWithError: NULL];
    }
}

- (void) volumeDidUnmount: (NSNotification *)notification
{
    NSURL *volumeURL = [notification.userInfo objectForKey: NSWorkspaceVolumeURLKey];
    if ([self.mountedVolumeURL isEqual: volumeURL])
    {
        self.mountedVolumeURL = nil;
        //Clear the flag so that if the volume is later remounted by someone else,
        //we won't decide to unmount it ourselves.
        self.unmountWhenDone = NO;
    }
}

- (void) volumeDidRename: (NSNotification *)notification
{
    NSURL *oldVolumeURL = [notification.userInfo objectForKey: NSWorkspaceVolumeOldURLKey];
    NSURL *newVolumeURL = [notification.userInfo objectForKey: NSWorkspaceVolumeURLKey];
    if ([self.mountedVolumeURL isEqual: oldVolumeURL])
        self.mountedVolumeURL = newVolumeURL;
}

- (NSURL *) volumeURLMountingIfNeeded: (BOOL)mountIfNeeded error: (out NSError **)outError
{
    //If we don't yet have a record of where the volume is mounted,
    //look it up now to see if it's already mounted. If it's not,
    //then try to mount it ourselves if we're allowed. Once we've
    //ascertained the location of the mounted volume, record it for
    //future use.
    if (!self.mountedVolumeURL)
    {
        NSWorkspace *ws = [NSWorkspace sharedWorkspace];
        NSArray *mountedURLs = [ws mountedVolumeURLsForSourceImageAtURL: self.baseURL];
        if (!mountedURLs.count && mountIfNeeded)
        {
            mountedURLs = [ws mountImageAtURL: self.baseURL
                                      options: ADBMountInvisible
                                        error: outError];
            
            if (mountedURLs)
            {
                //Flag that we mounted this volume ourselves, so that we'll unmount
                //it again when we're deallocated.
                self.unmountWhenDone = YES;
            }
            else
            {
                return nil;
            }
        }
        
        if (mountedURLs.count)
        {
            self.mountedVolumeURL = [mountedURLs objectAtIndex: 0];
        }
        else
        {
            if (outError)
            {
                *outError = [NSError errorWithDomain: ADBMountableImageErrorDomain
                                                code: ADBMountableImageVolumeUnavailable
                                            userInfo: nil];
            }
            return nil;
        }
    }
    
    return self.mountedVolumeURL;
}

- (BOOL) unmountVolumeWithError: (out NSError **)outError
{
    BOOL unmounted = [[NSWorkspace sharedWorkspace] unmountAndEjectDeviceAtURL: self.mountedVolumeURL
                                                                         error: outError];
    if (unmounted)
    {
        self.mountedVolumeURL = nil;
        self.unmountWhenDone = NO;
    }
    return unmounted;
}

#pragma mark - Path translation

- (NSString *) logicalPathForLocalFileURL: (NSURL *)URL
{
    NSString *relativePath = nil;
    NSURL *mountedURL = [self volumeURLMountingIfNeeded: YES error: NULL];
    if (!mountedURL)
        return nil;
    
    if ([URL isBasedInURL: mountedURL])
    {
        relativePath = [URL pathRelativeToURL: mountedURL];
        return [@"/" stringByAppendingPathComponent: relativePath];
    }
    else
    {
        return nil;
    }
}

- (NSURL *) localFileURLForLogicalPath: (NSString *)path
{
    //Ensure that paths such as "../path/outside/filesystem/" won't work
    path = path.stringByStandardizingPath;
    NSURL *mountedURL = [self volumeURLMountingIfNeeded: YES error: NULL];
    return [mountedURL URLByAppendingPathComponent: path];
}


- (ADBLocalDirectoryEnumerator *) enumeratorAtLocalFileURL: (NSURL *)URL
                                includingPropertiesForKeys: (NSArray *)keys
                                                   options: (NSDirectoryEnumerationOptions)mask
                                              errorHandler: (ADBFilesystemLocalFileURLErrorHandler)errorHandler
{
    NSError *mountingError = nil;
    NSURL *mountedURL = [self volumeURLMountingIfNeeded: YES error: &mountingError];
    if (mountedURL)
    {
        //Refuse to enumerate URLs that aren't located within this filesystem.
        if ([URL isBasedInURL: mountedURL])
        {
            return [[[ADBLocalDirectoryEnumerator alloc] initWithURL: URL
                                                         inFilesytem: self
                                          includingPropertiesForKeys: keys
                                                             options: mask
                                                          returnURLs: YES
                                                        errorHandler: errorHandler] autorelease];
        }
        else
        {
            if (errorHandler)
            {
                NSError *error = [NSError errorWithDomain: NSCocoaErrorDomain
                                                     code: NSFileReadNoSuchFileError
                                                 userInfo: @{ NSURLErrorKey: URL }];
                
                errorHandler(URL, error);
            }
            return nil;
        }
    }
    else
    {
        if (errorHandler)
            errorHandler(URL, mountingError);
        return nil;
    }
}
@end
