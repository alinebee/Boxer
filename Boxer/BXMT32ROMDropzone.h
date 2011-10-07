/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import "BXEmulatedMT32.h"


@interface BXMT32ROMDropzone : NSButton
{
    BXMT32ROMType _ROMType;
    BOOL _highlighted;
    
    CALayer *_backgroundLayer;
    CALayer *_CM32LLayer;
    CALayer *_MT32Layer;
    CATextLayer *_titleLayer;
}

//The type of MT-32 device to display (or BXMT32ROMTypeUnknown for no device.)
@property (assign, nonatomic) BXMT32ROMType ROMType;

//Whether the dropzone is highlighted for a drag-drop operation.
@property (assign, nonatomic, getter=isHighlighted) BOOL highlighted;

@end
