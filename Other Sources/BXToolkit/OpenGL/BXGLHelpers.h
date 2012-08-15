/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>


#pragma mark -
#pragma mark Error constants

//The error domain for errors produced by standard GL calls.
extern NSString * const BXGLErrorDomain;

//The error domain for errors produced by GL_EXT_framebuffer_object extension.
extern NSString * const BXGLFramebufferExtensionErrorDomain;



#pragma mark -
#pragma mark Helper functions

//Returns a Cocoa error object representing the specified GL error code.
//The error will be in the BXGLErrorDomain.
NSError *errorForGLErrorCode(GLenum errorCode);

//Returns a Cocoa error object representing the specified status code
//from the GL_FRAMEBUFFER_EXT extension. The error will be in the
//BXGLFramebufferExtensionErrorDomain.
//Will return nil if the status is GL_FRAMEBUFFER_COMPLETE_EXT, as this
//indicates a successful operation.
NSError *errorForGLFramebufferExtensionStatus(GLenum status);

//Returns a Cocoa error object representing the OpenGL error that occurred
//when processing the most recent GL command in the specified context.
//Returns nil if no error has occurred.
NSError *latestErrorInCGLContext(CGLContextObj context);
