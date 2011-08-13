/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXISOImage represents the filesystem of an ISO 9660-format (.ISO, .CDR, .BIN/CUE) image.
//It provides information about the structure of the image and allows its contents to be
//iterated and extracted.

#import <Foundation/Foundation.h>
#import "BXISOImageConstants.h"


#pragma mark -
#pragma mark Public interface


@protocol BXFilesystemEnumeration;
@interface BXISOImage : NSObject
{
    NSFileHandle *imageHandle;
    NSString *sourcePath;
    NSString *volumeName;
    
    unsigned long long imageSize;
    
    NSUInteger sectorSize;
    NSUInteger rawSectorSize;
    NSUInteger leadInSize;
    
    NSMutableDictionary *pathCache;
    
    BXISOPrimaryVolumeDescriptor primaryVolumeDescriptor;
}

//The source path of the image file from which this is loaded.
@property (readonly, nonatomic) NSString *sourcePath;

//The name of the image volume.
@property (readonly, nonatomic) NSString *volumeName;


#pragma mark -
#pragma mark Instance methods

//Return an image loaded from the image file at the specified source path.
//Returns nil if the image at the specified path could not be read.
+ (id) imageFromContentsOfFile: (NSString *)sourcePath error: (NSError **)outError;
- (id) initWithContentsOfFile: (NSString *)sourcePath error: (NSError **)outError;


//Returns an NSFileManager-like dictionary of the filesystem attributes
//of the file at the specified path. Returns nil and populates outError
//if the file could not be accessed.
- (NSDictionary *) attributesOfFileAtPath: (NSString *)path
                                    error: (NSError **)outError;

//Returns the raw byte data of the file at the specified path within the image.
//The path should be relative to the root of the image.
//Returns nil and populates outError if the file's contents could not be read.
- (NSData *) contentsOfFileAtPath: (NSString *)path
                            error: (NSError **)outError;

//Returns an NSDirectoryEnumerator-alike enumerator for the directory structure
//of this image, starting at the specified file path. Returns nil and populates outError
//if the specified path could not be located for some reason.
//If path is nil, the root path of the image will be used.
- (id <BXFilesystemEnumeration>) enumeratorAtPath: (NSString *)path
                                            error: (NSError **)outError;

@end