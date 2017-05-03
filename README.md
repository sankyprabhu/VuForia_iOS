# VuForia_iOS
Augmented Reality: Vuforia iOS Native Custom rendering and Touch interaction

## Requirement

* Xcode 8.3
* iOS 10.3
* Vuforia SDK for iOS v6.2.9

## AR principles

* The AR in this context means reconstructing the marker's relative 3D position towards a camera from the 2D image which taken by the camera. The process is:

* Convert Marker Coordinate (World Coordinate; its origin is a maker's position. 3D.) to Camera Coordinate(its origin is camera's position. 3D), which means get the marker's relative position seen by the camera.
* Convert Camera Coordinate (3D) to final 2D coordinate.

In reality, you don't have to do the matrix calculation every frame and leave that to the 3D library. For example, Using OpenGL, set perspective projection matrix using intrinsic matrix and model view matrix using extrins matrix, OpenGL reproduces the relation between the marker and the camera. Samples in Vuforia uses OpenGL and be implemented in this way.

* This process is located at renderFrameQCAR method in UserDefinedTargetsEAGLView.mm

* The process obtaining model view matrix from extrinsic parameter which caluclated by Vuforia is:

QCAR::Matrix44F modelViewMatrix = QCAR::Tool::convertPose2GLMatrix(result->getPose());`

* And obtaining perspective projection matrix from intrinsic matrix is:

&vapp.projectionMatrix.data[0]

