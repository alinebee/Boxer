/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>


#pragma mark -
#pragma mark Constants

#define BXShaderUnsupportedUniformLocation -1


#pragma mark -
#pragma mark Error constants

enum {
    BXShaderCouldNotCompileVertexShader,    //Vertex shader source code could not be compiled.
    BXShaderCouldNotCompileFragmentShader,  //Fragment shader source code could not be compiled.
    BXShaderCouldNotCreateShaderProgram,    //Failed to create a shader program from the specified
                                            //vertex and/or fragment shader.
};

//The domain for errors produced by BXShader.
extern NSString * const BXShaderErrorDomain;

//For compilation errors, contains the source code and info log of the offending shader.
extern NSString * const BXShaderErrorSourceKey;
extern NSString * const BXShaderErrorInfoLogKey;


#pragma mark -
#pragma mark Interface declaration

@interface BXShader : NSObject
{
    GLhandleARB _shaderProgram;
    
    //Whether to delete the shader when this is deallocated.
    BOOL _freeShaderWhenDone;
}

//The program underpinning this shader.
@property (readonly, nonatomic) GLhandleARB shaderProgram;


#pragma mark -
#pragma mark Helper class methods

//Returns the contents of the info log for the specified object
//(normally a shader or shader program).
+ (NSString *) infoLogForObject: (GLhandleARB)objectHandle;

//Compiles the specified shader source code of the specified type,
//and returns a handle for the new shader object.
//Returns NULL and populates outError if the shader could not be compiled.
+ (GLhandleARB) createShaderWithSource: (NSString *)source
                                  type: (GLenum)shaderType
                                 error: (NSError **)outError;

//Returns a shader program compiled and linked with the specified vertex shader
//and/or fragment shaders, provided as source strings.
//Returns NULL and populates outError if the shaders could not be compiled
//or the program could not be linked.
+ (GLhandleARB) createProgramWithVertexShader: (NSString *)vertexSource
                              fragmentShaders: (NSArray *)fragmentSources
                                        error: (NSError **)outError;


#pragma mark -
#pragma mark Initialization

//Shorthands for loading a shader from the main bundle,
//composed of a [shaderName].frag+[shaderName].vert pair.
+ (id) shaderNamed: (NSString *)shaderName
             error: (NSError **)outError;

+ (id) shaderNamed: (NSString *)shaderName
    inSubdirectory: (NSString *)subdirectory
             error: (NSError **)outError;

//Returns a new shader compiled from the specified vertex shader and/or fragment shaders,
//passed as source code. Returns nil and populates outError if the shader could not be compiled.
- (id) initWithVertexShader: (NSString *)vertexSource
            fragmentShaders: (NSArray *)fragmentSources
                      error: (NSError **)outError;

//Same as above, but loading the shader data from files on disk.
- (id) initWithContentsOfVertexShaderURL: (NSURL *)vertexShaderURL
                      fragmentShaderURLs: (NSArray *)fragmentShaderURLs
                                   error: (NSError **)outError;


#pragma mark -
#pragma mark Behaviour

//Set this shader to use different shader program. If freeWhenDone is YES,
//this shader will be deleted once the shader is deallocated.
- (void) setShaderProgram: (GLhandleARB)shaderProgram freeWhenDone: (BOOL)freeWhenDone;

//Returns the location of the specified uniform, for calls to glUniformXxARB() 
- (GLint) locationOfUniform: (const GLcharARB *)uniformName;

@end