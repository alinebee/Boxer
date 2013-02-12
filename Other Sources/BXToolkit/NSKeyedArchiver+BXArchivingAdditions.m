/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "NSKeyedArchiver+BXArchivingAdditions.h"

@implementation NSKeyedArchiver (BXArchivingAdditions)

+ (NSData *) archivedDataWithRootObject: (id)rootObject
                               delegate: (id <NSKeyedArchiverDelegate>)delegate
{
    NSMutableData *data = [[NSMutableData alloc] init];
    NSKeyedArchiver *archiver = [[self alloc] initForWritingWithMutableData: data];
    archiver.delegate = delegate;
    
    [archiver encodeRootObject: rootObject];
    
    [archiver finishEncoding];
    [archiver release];
    
    return [data autorelease];
}

@end

@implementation NSKeyedUnarchiver (BXUnarchivingAdditions)

+ (id) unarchiveObjectWithData: (NSData *)data
                      delegate: (id <NSKeyedUnarchiverDelegate>)delegate
{
    NSKeyedUnarchiver *unarchiver = [[self alloc] initForReadingWithData: data];
    unarchiver.delegate = delegate;
    
    id object = [unarchiver decodeObject];
    
    [unarchiver finishDecoding];
    [unarchiver release];
    
    return object;
}

@end