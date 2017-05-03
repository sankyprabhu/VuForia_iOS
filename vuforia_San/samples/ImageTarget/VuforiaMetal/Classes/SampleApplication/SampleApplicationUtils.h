/*===============================================================================
 Copyright (c) 2016 PTC Inc. All Rights Reserved. Confidential and Proprietary -
 Protected under copyright and other laws.
 Vuforia is a trademark of PTC Inc., registered in the United States and other
 countries.
 ===============================================================================*/

#ifndef __SHADERUTILS_H__
#define __SHADERUTILS_H__


#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>


namespace SampleApplicationUtils
{
    // Print a 4x4 matrix
    void printMatrix(const float* matrix);
    
    // Set the rotation components of a 4x4 matrix
    void setRotationMatrix(float angle, float x, float y, float z, 
                           float *nMatrix);
    
    // Set the translation components of a 4x4 matrix
    void translatePoseMatrix(float x, float y, float z,
                             float* nMatrix = NULL);
    
    // Apply a rotation
    void rotatePoseMatrix(float angle, float x, float y, float z, 
                          float* nMatrix = NULL);
    
    // Apply a scaling transformation
    void scalePoseMatrix(float x, float y, float z, 
                         float* nMatrix = NULL);
    
    // Multiply the two matrices A and B and write the result to C
    void multiplyMatrix(float *matrixA, float *matrixB, 
                        float *matrixC);
    
    void setOrthoMatrix(float nLeft, float nRight, float nBottom, float nTop,
                        float nNear, float nFar, float *nProjMatrix);
    
    void screenCoordToCameraCoord(int screenX, int screenY, int screenDX, int screenDY,
                                  int screenWidth, int screenHeight, int cameraWidth, int cameraHeight,
                                  int * cameraX, int* cameraY, int * cameraDX, int * cameraDY);
}

#endif  // __SHADERUTILS_H__
