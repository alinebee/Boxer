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

//ADBShader is an Objective-C wrapper for a GLSL shader program, providing simple shader
//loading and compilation and allowing introspection of the shader's available uniforms.

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Error constants

enum {
    ADBShaderCouldNotCompileVertexShader,   //Vertex shader source code could not be compiled.
    ADBShaderCouldNotCompileFragmentShader, //Fragment shader source code could not be compiled.
    ADBShaderCouldNotCreateShaderProgram,   //Failed to create a shader program from the specified
                                            //vertex and/or fragment shader.
};

/// The domain for errors produced by ADBShader.
extern NSErrorDomain const ADBShaderErrorDomain;

/// For compilation errors, contains the source code and info log of the offending shader.
extern NSErrorUserInfoKey const ADBShaderErrorSourceKey;
extern NSErrorUserInfoKey const ADBShaderErrorInfoLogKey;


#pragma mark -
#pragma mark Shader description constants

/// Returned by locationOfUniform: for unrecognised uniform names.
#define ADBShaderUnsupportedUniformLocation -1

//Keys for uniform description dictionaries.

/// An NSString representing the name of the uniform.
extern NSString * const ADBShaderUniformNameKey;

/// An NSNumber representing the location at which values can be assigned to the uniform.
extern NSString * const ADBShaderUniformLocationKey;

/// An NSNumber representing the uniform's index in the list of active uniforms.
extern NSString * const ADBShaderUniformIndexKey;

/// An NSNumber representing the uniform's type.
extern NSString * const ADBShaderUniformTypeKey;

/// An NSNumber representing the uniform's size.
extern NSString * const ADBShaderUniformSizeKey;


#pragma mark -
#pragma mark Interface declaration

@interface ADBShader : NSObject
{
    CGLContextObj _context;
    
    GLhandleARB _shaderProgram;
    
    //Whether to delete the shader program when this shader is deallocated.
    BOOL _freeProgramWhenDone;
}

/// The program underpinning this shader.
@property (readonly, nonatomic, nullable) GLhandleARB shaderProgram;

/// The context in which this shader was created.
@property (readonly, nonatomic) CGLContextObj context;


#pragma mark -
#pragma mark Helper class methods

//Returns an array of dictionaries describing the active uniforms
//defined in the specified shader program.
//See the key constants above for what is included in this dictionary.
+ (NSArray<NSDictionary<NSString*,id>*> *) uniformDescriptionsForShaderProgram: (GLhandleARB)shaderProgram
                                                                     inContext: (CGLContextObj)context;

//Returns the contents of the info log for the specified object
//(normally a shader or shader program).
+ (NSString *) infoLogForObject: (GLhandleARB)objectHandle inContext: (CGLContextObj)context;

/// Compiles the specified shader source code of the specified type,
/// and returns a handle for the new shader object.
/// Returns \c NULL and populates \c outError if the shader could not be compiled.
+ (nullable GLhandleARB) createShaderWithSource: (NSString *)source
                                           type: (GLenum)shaderType
                                      inContext: (CGLContextObj)context
                                          error: (NSError **)outError;

/// Returns a shader program compiled and linked with the specified vertex shader
/// and/or fragment shaders, provided as source strings.
/// Returns \c NULL and populates \c outError if the shaders could not be compiled
/// or the program could not be linked.
+ (nullable GLhandleARB) createProgramWithVertexShader: (NSString *)vertexSource
                                       fragmentShaders: (NSArray<NSString*> *)fragmentSources
                                             inContext: (CGLContextObj)context
                                                 error: (NSError **)outError;


#pragma mark -
#pragma mark Initialization

/// Shorthands for loading a shader from the main bundle,
/// composed of a [shaderName].frag+[shaderName].vert pair.
+ (nullable instancetype) shaderNamed: (NSString *)shaderName
                     context: (CGLContextObj)context
                       error: (NSError **)outError;

+ (nullable instancetype) shaderNamed: (NSString *)shaderName
                subdirectory: (NSString *)subdirectory
                     context: (CGLContextObj)context
                       error: (NSError **)outError;

/// Returns a new shader compiled from the specified vertex shader and/or fragment shaders,
/// passed as source code. Returns \c nil and populates \c outError if the shader could not be compiled.
- (nullable instancetype) initWithVertexShader: (NSString *)vertexSource
                               fragmentShaders: (NSArray<NSString*> *)fragmentSources
                                     inContext: (CGLContextObj)context
                                         error: (NSError **)outError;

/// Same as above, but loading the shader data from files on disk.
- (nullable instancetype) initWithContentsOfVertexShaderURL: (NSURL *)vertexShaderURL
                                         fragmentShaderURLs: (NSArray<NSURL*> *)fragmentShaderURLs
                                                  inContext: (CGLContextObj)context
                                                      error: (NSError **)outError;


#pragma mark -
#pragma mark Behaviour

/// Set this shader to use the specified shader program (deleting any previous one if appropriate.)
/// If freeWhenDone is YES, the program will be deleted once the shader is deallocated.
- (void) setShaderProgram: (GLhandleARB)shaderProgram
             freeWhenDone: (BOOL)freeWhenDone;

/// Clears the shader program and all related resources, deleting the shader itself if \c freeWhenDone
/// was \c YES at the time the shader was assigned.<br>
/// After this, the shader should not be used unless \c setShaderProgram:freeWhenDone:
/// is called with another shader.
- (void) deleteShaderProgram;

/// Returns the location of the specified uniform, for calls to \c glUniformXxARB().
/// Returns \c ADBShaderUnsupportedUniformLocation if the shader program does not
/// contain that uniform.
- (GLint) locationOfUniform: (const GLcharARB *)uniformName;

/// Returns an array of NSDictionaries describing all of the active uniforms defined
/// in the shader program.
/// See the key constants above for what data is included in each dictionary.
- (NSArray<NSDictionary<NSString*, id>*> *) uniformDescriptions;

/// The info log for this shader program.
- (NSString *) infoLog;

@end

NS_ASSUME_NONNULL_END
