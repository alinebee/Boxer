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
#pragma mark Implementation

/// @c ADBGLTexture wraps an OpenGL texture, tracks information about its size
/// and parameters, and provides easy methods to write to and draw from it.
@interface ADBTexture2D : NSObject
{
    CGLContextObj _context;
    GLuint _texture;
    GLenum _type;
    CGSize _textureSize;
    CGRect _contentRegion;
    
    BOOL _usesNormalizedTextureCoordinates;
    
    GLenum _horizontalWrapping;
    GLenum _verticalWrapping;
    GLenum _minFilter;
    GLenum _magFilter;
}

/// The context in which this texture was created.
@property (readonly, nonatomic) CGLContextObj context;

/// The GL texture handle for this texture.
@property (readonly, nonatomic) GLuint texture;

//The type of this texture: one of GL_TEXTURE_2D or GL_TEXTURE_RECTANGLE.
@property (readonly, nonatomic) GLenum type;

/// The size in texels of this texture.
@property (readonly, nonatomic) CGSize textureSize;

/// The region (expressed in texels) of the texture that is filled by content:
/// i.e., the usable area of the texture.
/// This is used by drawOntoVertices:error: and other operations that work with
/// the texture content as a whole.
@property (assign, nonatomic) CGRect contentRegion;

/// The above expressed in normalized texture coordinates (0-1).
@property (assign, nonatomic) CGRect normalizedContentRegion;

/// Whether the texture uses texels or normalized (0-1) texture coordinates for draw functions.
/// Will be @c NO for @c GL_TEXTURE_RECTANGLE textures, @c YES for everything else.
@property (readonly, nonatomic) BOOL usesNormalizedTextureCoordinates;


//The texture's scaling and wrapping behaviour.
@property (assign, nonatomic) GLenum minFilter;
@property (assign, nonatomic) GLenum magFilter;
@property (assign, nonatomic) GLenum horizontalWrapping;
@property (assign, nonatomic) GLenum verticalWrapping;

/// Set the min and mag filter and texture wrapping mode simultaneously, which is more efficient.
- (void) setMinFilter: (GLenum)minFilter
            magFilter: (GLenum)magFilter
             wrapping: (GLenum)wrappingMode;

#pragma mark -
#pragma mark Initialization and texture copying

/// Returns a newly initialized texture for the specified content size and data.
/// If provided, the texture will be filled with bytes, assumed to be in the format
/// \c GL_BGRA and <code>GL_UNSIGNED_INT_8_8_8_8_REV</code>.
/// Returns \c nil and populates \c outError if there was an error and \c outError was provided.
+ (nullable instancetype) textureWithType: (GLenum)type
                              contentSize: (CGSize)size
                                    bytes: (nullable const GLvoid *)bytes
                              inGLContext: (CGLContextObj)context
                                    error: (NSError **)outError;

- (nullable instancetype) initWithType: (GLenum)type
                           contentSize: (CGSize)size
                                 bytes: (nullable const GLvoid *)bytes
                           inGLContext: (CGLContextObj)context
                                 error: (NSError **)outError;

/// Fills the specified region of the texture (expressed in texels)
/// with the specified bytes, assumed to be in the format \c GL_BGRA
/// and <code>GL_UNSIGNED_INT_8_8_8_8_REV</code>.<br>
/// Returns \c NO and populates \c outError if there was an error and \c outError was provided.
- (BOOL) fillRegion: (CGRect)region
          withBytes: (const GLvoid *)bytes
              error: (NSError **)outError;

/// Fills the specified region of the texture with the specified color values (ranging from 0 to 1).
/// Mostly used for blanking the texture.
- (BOOL) fillRegion: (CGRect)region
            withRed: (CGFloat)red
              green: (CGFloat)green
               blue: (CGFloat)blue
              alpha: (CGFloat)alpha
              error: (NSError **)outError;

/// Cleans up the texture resource. After this, the texture should not be used.
- (void) deleteTexture;

#pragma mark -
#pragma mark Drawing

/// Draw the specified region of the texture (expressed in normalized 0-1 coordinates)
/// onto the specified vertices (expressed as an array of coordinate pairs).
/// Returns NO and populates outError if there was an error and outError was provided.
- (BOOL) drawFromNormalizedRegion: (CGRect)region
                     ontoVertices: (GLfloat *)vertices
                            error: (NSError **)outError;

/// As above, but for a texture region expressed in texels.
- (BOOL) drawFromTexelRegion: (CGRect)region
                ontoVertices: (GLfloat *)vertices
                       error: (NSError **)outError;

/// Draws the entire content region of the texture onto the specified vertices.
- (BOOL) drawOntoVertices: (GLfloat *)vertices
                    error: (NSError **)outError;


#pragma mark -
#pragma mark Texture parameters

- (void) setIntValue: (GLint)value
        forParameter: (GLenum)parameter;


#pragma mark -
#pragma mark Framebuffers

/// Binds the texture to the specified framebuffer at the specified attachment point and level.
/// Returns NO and populates outError if the texture could not be bound.
- (BOOL) bindToFrameBuffer: (GLuint)framebuffer
                attachment: (GLenum)attachment
                     level: (GLint)level
                     error: (NSError **)outError;


#pragma mark -
#pragma mark Coordinates

/// Whether the texture's extents contain the specified texel region.
- (BOOL) containsRegion: (CGRect)region;

/// Whether the texture can contain the specified content size.
- (BOOL) canAccommodateContentSize: (CGSize)contentSize;

/// Functions to convert to and from texels (coordinates expressed as pixel measurements)
/// and normalized texture coordinates (coordinates in which the texture size is {1, 1}).
- (CGRect) normalizedRectFromTexelRect: (CGRect)rect;
- (CGSize) normalizedSizeFromTexelSize: (CGSize)size;
- (CGPoint) normalizedPointFromTexelPoint: (CGPoint)point;

- (CGRect) texelRectFromNormalizedRect: (CGRect)rect;
- (CGSize) texelSizeFromNormalizedSize: (CGSize)size;
- (CGPoint) texelPointFromNormalizedPoint: (CGPoint)point;

/// Converts from normalized/texel coordinates into whatever system the texture uses natively.
/// (This means texels for \c GL_TEXTURE_RECTANGLE textures and normalized coordinates for everyone else.)
- (CGRect) nativeRectFromTexelRect: (CGRect)rect;
- (CGRect) nativeRectFromNormalizedRect: (CGRect)rect;

#pragma mark -
#pragma mark Class helper methods

/// Returns the minimum size of texture required to accomodate the specified content size
/// given the specified texture type. Will return the original size for \c GL_TEXTURE_RECTANGLE type,
/// or the nearest larger power-of-two size for other types.
+ (CGSize) textureSizeNeededForContentSize: (CGSize)size
                                  withType: (GLenum)textureType;

@end


/// Private methods, intended for internal use by subclasses
@interface ADBTexture2D (ADBTexture2DPrivate)

/// Convenience method for checking if an error occurred in the previous operation.
/// Returns \c YES if no error occurred or if \c outError is \c NULL (which indicates that no
/// error-checking is desired by the calling context), or \c NO and populates \c outError
/// if an error has occurred.
- (BOOL) _checkForGLError: (NSError **)outError;

@end

NS_ASSUME_NONNULL_END
