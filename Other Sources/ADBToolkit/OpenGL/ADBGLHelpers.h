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

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Error constants

/// The error domain for errors produced by standard GL calls.
extern NSString * const ADBGLErrorDomain;

/// The error domain for errors produced by \c GL_EXT_framebuffer_object extension.
extern NSString * const ADBGLFramebufferExtensionErrorDomain;



#pragma mark -
#pragma mark Helper functions

/// Returns a Cocoa error object representing the specified GL error code.
/// The error will be in the ADBGLErrorDomain.
NSError *__nullable errorForGLErrorCode(GLenum errorCode);

/// Returns a Cocoa error object representing the specified status code
/// from the \c GL_FRAMEBUFFER_EXT extension. The error will be in the
/// \c ADBGLFramebufferExtensionErrorDomain.
/// Will return nil if the status is \c GL_FRAMEBUFFER_COMPLETE_EXT, as this
/// indicates a successful operation.
NSError *__nullable errorForGLFramebufferExtensionStatus(GLenum status);

/// Returns a Cocoa error object representing the OpenGL error that occurred
/// when processing the most recent GL command in the specified context.
/// Returns nil if no error has occurred.
NSError *__nullable latestErrorInCGLContext(CGLContextObj context);

NS_ASSUME_NONNULL_END
