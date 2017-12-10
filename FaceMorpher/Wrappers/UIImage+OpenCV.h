//
//  UIImage+OpenCV.h
//  FaceMorpher
//
//  Created by Dmitry Rybochkin on 29.11.2017.
//  Copyright © 2017 Dmitry Rybochkin. All rights reserved.
//

#import <opencv2/opencv.hpp>

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIImage (UIImage_OpenCV)

+(UIImage *)imageWithCVMat:(const cv::Mat&)cvMat;
-(id)initWithCVMat:(const cv::Mat&)cvMat;

@property(nonatomic, readonly) cv::Mat CVMat;
@property(nonatomic, readonly) cv::Mat CVGrayscaleMat;

@end
