/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import "BXEmulatedMT32.h"


@interface BXMT32ROMDropzone : NSButton <CALayerDelegate>
{
    BXMT32ROMType _ROMType;
    
    CALayer *_backgroundLayer;
    CALayer *_CM32LLayer;
    CALayer *_MT32Layer;
    CALayer *_highlightLayer;
    CATextLayer *_titleLayer;
}

/// The type of MT-32 device to display (or BXMT32ROMTypeUnknown for no device.)
@property (assign, nonatomic) BXMT32ROMType ROMType;

//Whether the dropzone is highlighted for a drag-drop operation.
//We now use NSControl's highlighted property.
//@property (assign, atomic, getter=isHighlighted) BOOL highlighted;

@end
