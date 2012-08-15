//
//  BXGLTexture.h
//  Boxer
//
//  Created by Alun Bestor on 03/06/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>


//BXGLTexture wraps an OpenGL texture, tracks information about its size
//and parameters, and provides easy methods to write to and draw from it.

#pragma mark -
#pragma mark Implementation

@interface BXTexture2D : NSObject
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

//The context in which this texture was created.
@property (readonly, nonatomic) CGLContextObj context;

//The GL texture handle for this texture.
@property (readonly, nonatomic) GLuint texture;

//The type of this texture: one of GL_TEXTURE_2D or GL_TEXTURE_RECTANGLE.
@property (readonly, nonatomic) GLenum type;

//The size in texels of this texture.
@property (readonly, nonatomic) CGSize textureSize;

//The region (expressed in texels) of the texture that is filled by content:
//i.e., the usable area of the texture.
//This is used by drawOntoVertices:error: and other operations that work with
//the texture content as a whole.
@property (assign, nonatomic) CGRect contentRegion;

//The above expressed in normalized texture coordinates (0-1).
@property (assign, nonatomic) CGRect normalizedContentRegion;

//Whether the texture uses texels or normalized (0-1) texture coordinates for draw functions.
//Will be NO for GL_TEXTURE_RECTANGLE textures, YES for everything else.
@property (readonly, nonatomic) BOOL usesNormalizedTextureCoordinates;


//The texture's scaling and wrapping behaviour.
@property (assign, nonatomic) GLenum minFilter;
@property (assign, nonatomic) GLenum magFilter;
@property (assign, nonatomic) GLenum horizontalWrapping;
@property (assign, nonatomic) GLenum verticalWrapping;

//Set the min and mag filter and texture wrapping mode simultaneously, which is more efficient.
- (void) setMinFilter: (GLenum)minFilter
            magFilter: (GLenum)magFilter
             wrapping: (GLenum)wrappingMode;

#pragma mark -
#pragma mark Initialization and texture copying

//Returns a newly initialized texture for the specified content size and data.
//If provided, the texture will be filled with bytes, assumed to be in the format
//GL_BGRA and GL_UNSIGNED_INT_8_8_8_8_REV.
//Returns nil and populates outError if there was an error and outError was provided.
+ (id) textureWithType: (GLenum)type
           contentSize: (CGSize)size
                 bytes: (const GLvoid *)bytes
           inGLContext: (CGLContextObj)context
                 error: (NSError **)outError;

- (id) initWithType: (GLenum)type
        contentSize: (CGSize)size
              bytes: (const GLvoid *)bytes
        inGLContext: (CGLContextObj)context
              error: (NSError **)outError;

//Fills the specified region of the texture (expressed in texels)
//with the specified bytes, assumed to be in the format GL_BGRA
//and GL_UNSIGNED_INT_8_8_8_8_REV.
//Returns NO and populates outError if there was an error and outError was provided.
- (BOOL) fillRegion: (CGRect)region
          withBytes: (const GLvoid *)bytes
              error: (NSError **)outError;

//Fills the specified region of the texture with the specified color values (ranging from 0 to 1).
//Mostly used for blanking the texture.
- (BOOL) fillRegion: (CGRect)region
            withRed: (CGFloat)red
              green: (CGFloat)green
               blue: (CGFloat)blue
              alpha: (CGFloat)alpha
              error: (NSError **)outError;

//Cleans up the texture resource. After this, the texture should not be used.
- (void) deleteTexture;

#pragma mark -
#pragma mark Drawing

//Draw the specified region of the texture (expressed in normalized 0-1 coordinates)
//onto the specified vertices (expressed as an array of coordinate pairs).
//Returns NO and populates outError if there was an error and outError was provided.
- (BOOL) drawFromNormalizedRegion: (CGRect)region
                     ontoVertices: (GLfloat *)vertices
                            error: (NSError **)outError;

//As above, but for a texture region expressed in texels. 
- (BOOL) drawFromTexelRegion: (CGRect)region
                ontoVertices: (GLfloat *)vertices
                       error: (NSError **)outError;

//Draws the entire content region of the texture onto the specified vertices.
- (BOOL) drawOntoVertices: (GLfloat *)vertices
                    error: (NSError **)outError;


#pragma mark -
#pragma mark Texture parameters

- (void) setIntValue: (GLint)value
        forParameter: (GLenum)parameter;


#pragma mark -
#pragma mark Framebuffers

//Binds the texture to the specified framebuffer at the specified attachment point and level.
//Returns NO and populates outError if the texture could not be bound.
- (BOOL) bindToFrameBuffer: (GLuint)framebuffer
                attachment: (GLenum)attachment
                     level: (GLint)level
                     error: (NSError **)outError;


#pragma mark -
#pragma mark Coordinates

//Whether the texture's extents contain the specified texel region.
- (BOOL) containsRegion: (CGRect)region;

//Whether the texture can contain the specified content size.
- (BOOL) canAccomodateContentSize: (CGSize)contentSize;

//Functions to convert to and from texels (coordinates expressed as pixel measurements)
//and normalized texture coordinates (coordinates in which the texture size is {1, 1}).
- (CGRect) normalizedRectFromTexelRect: (CGRect)rect;
- (CGSize) normalizedSizeFromTexelSize: (CGSize)size;
- (CGPoint) normalizedPointFromTexelPoint: (CGPoint)point;

- (CGRect) texelRectFromNormalizedRect: (CGRect)rect;
- (CGSize) texelSizeFromNormalizedSize: (CGSize)size;
- (CGPoint) texelPointFromNormalizedPoint: (CGPoint)point;

//Converts from normalized/texel coordinates into whatever system the texture uses natively.
//(This means texels for GL_TEXTURE_RECTANGLE textures and normalized coordinates for everyone else.)
- (CGRect) nativeRectFromTexelRect: (CGRect)rect;
- (CGRect) nativeRectFromNormalizedRect: (CGRect)rect;

#pragma mark -
#pragma mark Class helper methods

//Returns the minimum size of texture required to accomodate the specified content size
//given the specified texture type. Will return the original size for GL_TEXTURE_RECTANGLE type,
//or the nearest larger power-of-two size for other types.
+ (CGSize) textureSizeNeededForContentSize: (CGSize)size
                                  withType: (GLenum)textureType;

@end


//Private methods, intended for internal use by subclasses
@interface BXTexture2D (BXTexture2DPrivate)

//Convenience method for checking if an error occurred in the previous operation.
//Returns YES if no error occurred or if outError is NULL (which indicates that no
//error-checking is desired by the calling context), or NO and populates outError
//if an error has occurred.
- (BOOL) _checkForGLError: (NSError **)outError;

@end
