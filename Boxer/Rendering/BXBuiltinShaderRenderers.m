/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBuiltinShaderRenderers.h"

@implementation BXBuiltinShaderRenderer

- (id) initWithShaderNames: (NSArray *)shaderNames
                  atScales: (CGFloat *)scales
                 inContext: (CGLContextObj)glContext
                     error: (NSError **)outError
{
    NSMutableArray *shaderURLs = [NSMutableArray arrayWithCapacity: shaderNames.count];
    
    for (NSString *shaderName in shaderNames)
    {
        NSURL *shaderURL = [[NSBundle mainBundle] URLForResource: shaderName
                                                   withExtension: @"shader"
                                                    subdirectory: @"Shaders"];
        
        NSAssert1(shaderURL != nil, @"Shader not found in Shaders subdirectory: %@", shaderName);
        
        [shaderURLs addObject: shaderURL];
    }
    
    return [self initWithContentsOfURLs: shaderURLs atScales: scales inContext: glContext error: outError];
}

@end


@implementation BXSmoothedRenderer

- (id) initWithContext: (CGLContextObj)glContext error: (NSError **)outError
{
    NSArray *shaderNames = [NSArray arrayWithObjects: @"5xBR Semi-Rounded-unclamped", @"5xBR Semi-Rounded-clamped", nil];
    CGFloat scales[] = { 1.25, 5.0, };
    
    return [self initWithShaderNames: shaderNames atScales: scales inContext: glContext error: outError];
}

- (BOOL) usesShaderSupersampling
{
    return YES;
}

@end


@implementation BXCRTRenderer

- (id) initWithContext: (CGLContextObj)glContext error: (NSError **)outError
{
    NSArray *shaderNames = [NSArray arrayWithObjects: @"crt-geom-interlaced-curved", nil];
    CGFloat scales[] = { 1.0 };
    
    return [self initWithShaderNames: shaderNames atScales: scales inContext: glContext error: outError];
}

- (BOOL) usesShaderSupersampling
{
    return NO;
}

@end