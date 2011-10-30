/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "CALayer+BXLayerAdditions.h"

@implementation CALayer (BXLayerAdditions)

- (void) setContentsFromImageNamed: (NSString *)imageName
{
    NSString *imagePath = [[NSBundle mainBundle] pathForImageResource: imageName];
    NSURL *imageURL = [NSURL fileURLWithPath: imagePath];
    
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL((CFURLRef)imageURL, NULL);
    if (imageSource)
    {
        CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
        
        self.contents = (id)image;
        
        CFRelease(imageSource);
        CFRelease(image);
    }
}

@end
