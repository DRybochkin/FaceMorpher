//
//  OpenCVWrapper.h
//  FaceMorpher
//
//  Created by Dmitry Rybochkin on 29.11.2017.
//  Copyright © 2017 Dmitry Rybochkin. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface OpenCVWrapper : NSObject

-(NSString *) openCVVersionString;
-(void) loadHaarCascades:(NSString*)faceCascadeName :(NSString*)eyeCascadeName :(NSString*)noseCascadeName :(NSString*) mouthCascadeName;
-(NSArray<NSValue *>*) processFrame:(CVPixelBufferRef)pixelBuffer :(AVCaptureVideoOrientation)videOrientation :(CGFloat)scaleFactor :(BOOL)isSingleFace;

@end
