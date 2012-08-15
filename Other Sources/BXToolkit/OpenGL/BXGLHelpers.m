/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXGLHelpers.h"
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>
#import <OpenGL/CGLMacro.h>

NSString * const BXGLErrorDomain = @"BXGLErrorDomain";
NSString * const BXGLFramebufferExtensionErrorDomain = @"BXGLFramebufferExtensionErrorDomain";


NSError *errorForGLErrorCode(GLenum errCode)
{
    const GLubyte *errString = gluErrorString(errCode);
    
    NSString *errorDescription = [NSString stringWithCString: (const char *)errString
                                                    encoding: NSASCIIStringEncoding];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject: errorDescription
                                                         forKey: NSLocalizedFailureReasonErrorKey];
    
    return [NSError errorWithDomain: BXGLErrorDomain code: errCode userInfo: userInfo];
}

NSError *errorForGLFramebufferExtensionStatus(GLenum status)
{
    if (status == GL_FRAMEBUFFER_COMPLETE_EXT)
        return nil;
    
    //TODO: populate a localized error description based on the status code.
    return [NSError errorWithDomain: BXGLFramebufferExtensionErrorDomain
                               code: status
                           userInfo: nil];
}

NSError *latestErrorInCGLContext(CGLContextObj context)
{
    CGLContextObj cgl_ctx = context;
    GLenum errCode = glGetError();
    if (errCode)
    {
        return errorForGLErrorCode(errCode);
    }
    else
    {
        return nil;
    }
}
