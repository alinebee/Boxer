/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXDrive+BXDriveArchiving.h"
#import "BXDrivePrivate.h"
#import "NSURL+ADBAliasHelpers.h"


//Used when decoding drive records from previous Boxer versions,
//to decide whether to resolve bookmarks or aliases.
#define BXCurrentDriveEncodingVersion 1400
#define BXFirstBookmarkSupportingVersion 1400


//Used for decoding NDAlias-encoded paths from previous Boxer versions.
@interface __NDAliasDecoder : NSObject
@end

@implementation __NDAliasDecoder

//NDAlias encoded its internal alias record as an NSData object;
//we no longer use NDAlias, but we can convert its alias record
//into modern bookmark data. This class is substituted for NDAlias
//during decoding and returns the decoded NSData object directly.
- (id) initWithCoder: (NSCoder *)aDecoder
{
    [self release];
    return (id)[[aDecoder decodeDataObject] retain];
}

@end


@implementation BXDrive (BXDriveArchiving)

- (id) initWithCoder: (NSCoder *)aDecoder
{
    if ((self = [self init]))
    {
        NSInteger encodingVersion = [aDecoder decodeIntegerForKey: @"encodingVersion"];
        
        //Paths were encoded as OS X 10.6+ bookmark data
        if (encodingVersion >= BXFirstBookmarkSupportingVersion)
        {
#define URL_FROM_BOOKMARK(bookmark) ((NSURL *)[NSURL URLByResolvingBookmarkData: bookmark options: NSURLBookmarkResolutionWithoutUI relativeToURL: nil bookmarkDataIsStale: NULL error: NULL])
            
            NSData *sourcePathBookmarkData = [aDecoder decodeObjectForKey: @"sourceURLBookmark"];
            if (sourcePathBookmarkData)
            {
                self.sourceURL = URL_FROM_BOOKMARK(sourcePathBookmarkData);
            }
            //If we couldn't resolve the bookmark to this drive's path, this drive is useless
            //and we shouldn't bother continuing.
            if (self.sourceURL == nil)
            {
                [self release];
                return nil;
            }
            
            NSData *shadowPathBookmarkData = [aDecoder decodeObjectForKey: @"shadowURLBookmark"];
            if (shadowPathBookmarkData)
            {
                self.shadowURL = URL_FROM_BOOKMARK(shadowPathBookmarkData);
            }
            
            NSData *mountPointBookmarkData = [aDecoder decodeObjectForKey: @"mountPointURLBookmark"];
            if (mountPointBookmarkData)
            {
                self.mountPointURL = URL_FROM_BOOKMARK(mountPointBookmarkData);
            }
            
            NSSet *equivalentURLBookmarks = [aDecoder decodeObjectForKey: @"equivalentURLBookmarks"];
            if (equivalentURLBookmarks)
            {
                for (NSData *bookmarkData in equivalentURLBookmarks)
                {
                    NSURL *equivalentURL = URL_FROM_BOOKMARK(bookmarkData);
                    if (equivalentURL)
                        [self.equivalentURLs addObject: equivalentURL];
                }
            }
        }
        
        //Paths were encoded as legacy alias data
        else
        {
#define URL_FROM_ALIAS(alias) ((NSURL *)[NSURL URLByResolvingAliasRecord: alias options: NSURLBookmarkResolutionWithoutUI relativeToURL: nil bookmarkDataIsStale: NULL error: NULL])
            
            //IMPLEMENTATION NOTE: previous Boxer versions encoded paths as NDAlias instances.
            //We no longer use NDAlias in favour of NSURL bookmarks, but we can still resolve encoded
            //NDAlias instances as NSData instances representing serialized alias records.
            if ([aDecoder respondsToSelector: @selector(setClass:forClassName:)])
                [(NSKeyedUnarchiver *)aDecoder setClass: [__NDAliasDecoder class]
                                           forClassName: @"NDAlias"];
            
            NSData *sourcePathAliasData = [aDecoder decodeObjectForKey: @"path"];
            if (sourcePathAliasData)
            {
                self.sourceURL = URL_FROM_ALIAS(sourcePathAliasData);
            }
            
            if (self.sourceURL == nil)
            {
                [self release];
                return nil;
            }
            
            NSData *shadowPathAliasData = [aDecoder decodeObjectForKey: @"shadowPath"];
            if (shadowPathAliasData)
                self.shadowURL = URL_FROM_ALIAS(shadowPathAliasData);
            
            NSData *mountPointAliasData = [aDecoder decodeObjectForKey: @"mountPoint"];
            if (mountPointAliasData)
                self.mountPointURL = URL_FROM_ALIAS(mountPointAliasData);
            
            NSSet *pathAliases = [aDecoder decodeObjectForKey: @"pathAliases"];
            for (NSData *aliasData in pathAliases)
            {
                NSURL *equivalentURL = URL_FROM_ALIAS(aliasData);
                if (equivalentURL)
                    [self.equivalentURLs addObject: equivalentURL];
            }
        }
        
        self.type = [aDecoder decodeIntegerForKey: @"type"];
        
        NSString *letter = [aDecoder decodeObjectForKey: @"letter"];
        if (letter) self.letter = letter;
        
        NSString *title = [aDecoder decodeObjectForKey: @"title"];
        if (title) self.title = title;
        
        NSString *volumeLabel = [aDecoder decodeObjectForKey: @"volumeLabel"];
        if (volumeLabel) self.volumeLabel = volumeLabel;
        
        if ([aDecoder containsValueForKey: @"freeSpace"])
            self.freeSpace  = [aDecoder decodeIntegerForKey: @"freeSpace"];
        
        if ([aDecoder containsValueForKey: @"usesCDAudio"])
            self.usesCDAudio = [aDecoder decodeBoolForKey: @"usesCDAudio"];
        
        self.readOnly   = [aDecoder decodeBoolForKey: @"readOnly"];
        self.locked     = [aDecoder decodeBoolForKey: @"locked"];
        self.hidden     = [aDecoder decodeBoolForKey: @"hidden"];
        self.mounted    = [aDecoder decodeBoolForKey: @"mounted"];
    }
    
    return self;
}

- (void) encodeWithCoder: (NSCoder *)aCoder
{
    NSAssert1(self.sourceURL != nil, @"Attempt to serialize virtual drive or drive missing URL: %@", self);
    
#define BOOKMARK_FROM_URL(url) ((NSData *)[url bookmarkDataWithOptions: 0 includingResourceValuesForKeys: nil relativeToURL: nil error: NULL])
    
    //Convert all paths to bookmarks before encoding, so that we can track them if they move.
    NSData *sourceURLBookmark = BOOKMARK_FROM_URL(self.sourceURL);
    [aCoder encodeObject: sourceURLBookmark forKey: @"sourceURLBookmark"];
    
    [aCoder encodeInteger: self.type forKey: @"type"];
    
    if (self.letter)
        [aCoder encodeObject: self.letter forKey: @"letter"];
    
    if (self.shadowPath)
    {
        NSData *shadowURLBookmark = BOOKMARK_FROM_URL(self.shadowURL);
        [aCoder encodeObject: shadowURLBookmark forKey: @"shadowURLBookmark"];
    }
    
    //For other paths and strings, only bother recording them if they have been
    //manually changed from their autodetected versions.
    if (self.mountPoint && !_hasAutodetectedMountPoint)
    {
        NSData *mountPointURLBookmark = BOOKMARK_FROM_URL(self.mountPointURL);
        [aCoder encodeObject: mountPointURLBookmark forKey: @"mountPointURLBookmark"];
    }
    
    if (self.title && !_hasAutodetectedTitle)
    {
        [aCoder encodeObject: self.title forKey: @"title"];
    }
    
    if (self.volumeLabel && !_hasAutodetectedVolumeLabel)
        [aCoder encodeObject: self.volumeLabel forKey: @"volumeLabel"];
    
    if (self.equivalentURLs.count)
    {
        NSMutableSet *equivalentURLBookmarks = [[NSMutableSet alloc] initWithCapacity: self.equivalentURLs.count];
        
        for (NSURL *equivalentURL in self.equivalentURLs)
        {
            NSData *bookmarkData = BOOKMARK_FROM_URL(equivalentURL);
            [equivalentURLBookmarks addObject: bookmarkData];
        }
        
        [aCoder encodeObject: equivalentURLBookmarks forKey: @"equivalentURLBookmarks"];
        [equivalentURLBookmarks release];
    }
    
    //For scalar properties, we only bother recording exceptions to the defaults
    if (self.freeSpace != BXDefaultFreeSpace)
        [aCoder encodeInteger: self.freeSpace forKey: @"freeSpace"];
    
    if (self.readOnly)
        [aCoder encodeBool: self.readOnly forKey: @"readOnly"];
    
    if (self.hidden)
        [aCoder encodeBool: self.hidden forKey: @"hidden"];
    
    if (self.locked)
        [aCoder encodeBool: self.locked forKey: @"locked"];
    
    if (self.isMounted)
        [aCoder encodeBool: self.isMounted forKey: @"mounted"];
    
    if (!self.usesCDAudio)
        [aCoder encodeBool: self.usesCDAudio forKey: @"usesCDAudio"];
    
    [aCoder encodeInteger: BXCurrentDriveEncodingVersion forKey: @"encodingVersion"];
}

@end
