//
//  OpenCVWrapper.m
//  FaceMorpher
//
//  Created by Dmitry Rybochkin on 29.11.2017.
//  Copyright © 2017 Dmitry Rybochkin. All rights reserved.
//

#define CV_HAAR_DO_CANNY_PRUNING    1
#define CV_HAAR_SCALE_IMAGE         2
#define CV_HAAR_FIND_BIGGEST_OBJECT 4
#define CV_HAAR_DO_ROUGH_SEARCH     8


#import <opencv2/opencv.hpp>

#import "OpenCVWrapper.h"

//const int kHaarAllOptions = CV_HAAR_DO_CANNY_PRUNING | CV_HAAR_SCALE_IMAGE | CV_HAAR_FIND_BIGGEST_OBJECT | CV_HAAR_DO_ROUGH_SEARCH;
const int kHaarSingleFaceOptions = CV_HAAR_SCALE_IMAGE | CV_HAAR_FIND_BIGGEST_OBJECT;
const int kHaarMultieFaceOptions = CV_HAAR_SCALE_IMAGE | CV_HAAR_DO_ROUGH_SEARCH;
const int kHaarFeaturesOptions = 0 | CV_HAAR_SCALE_IMAGE;

@implementation OpenCVWrapper

cv::CascadeClassifier _faceCascade;
cv::CascadeClassifier _eyesCascade;
cv::CascadeClassifier _noseCascade;
cv::CascadeClassifier _mouthCascade;

-(NSString *) openCVVersionString
{
    return [NSString stringWithFormat:@"OpenCV Version %s", CV_VERSION];
}

-(void) loadHaarCascades: (NSString*)faceCascadeName :(NSString*)eyeCascadeName :(NSString*)noseCascadeName :(NSString*) mouthCascadeName {
    _faceCascade = [self loadHaarCascade: faceCascadeName];
    _eyesCascade = [self loadHaarCascade: eyeCascadeName];
    _noseCascade = [self loadHaarCascade: noseCascadeName];
    _mouthCascade = [self loadHaarCascade: mouthCascadeName];
}

-(cv::CascadeClassifier) loadHaarCascade: (NSString*) cascadeName {
    cv::CascadeClassifier cascade;
    if (cascadeName.length != 0) {
        NSString *cascadePath = [[NSBundle mainBundle] pathForResource:cascadeName ofType:@"xml"];
        
        
        if (!cascade.load([cascadePath UTF8String])) {
            NSLog(@"Could not load face cascade: %@", cascadePath);
        }
    }
    return cascade;
}


-(NSArray<NSValue *>*) processFrame:(CVPixelBufferRef)pixelBuffer :(AVCaptureVideoOrientation)videOrientation :(CGFloat)scaleFactor :(BOOL)isSingleObject {
    OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
    CGRect videoRect = CGRectMake(0.0f, 0.0f, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
    
    NSArray<NSValue *>* faces = nil;
    
    if (format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void *baseaddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        
        cv::Mat mat(videoRect.size.height, videoRect.size.width, CV_8UC1, baseaddress, 0);
        
        faces = [self processFrame:mat videoRect:videoRect videoOrientation:videOrientation scaleFactor: scaleFactor isSingleFace: isSingleObject];
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    } else if (format == kCVPixelFormatType_32BGRA) {
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        void *baseaddress = CVPixelBufferGetBaseAddress(pixelBuffer);
        
        cv::Mat mat(videoRect.size.height, videoRect.size.width, CV_8UC4, baseaddress, 0);
        
        faces = [self processFrame:mat videoRect:videoRect videoOrientation:videOrientation scaleFactor: scaleFactor isSingleFace: isSingleObject];
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    } else {
        NSLog(@"Unsupported video format");
    }
    return faces;
}

- (NSArray<NSValue *>*) processFrame:(cv::Mat &)mat videoRect:(CGRect)rect videoOrientation:(AVCaptureVideoOrientation)videOrientation scaleFactor:(CGFloat) scaleFactor isSingleFace:(BOOL)isSingleFace
{
    cv::resize(mat, mat, cv::Size(), scaleFactor, scaleFactor, CV_INTER_LINEAR);
    rect.size.width *= scaleFactor;
    rect.size.height *= scaleFactor;

    if (videOrientation == AVCaptureVideoOrientationLandscapeRight && UIDeviceOrientationIsPortrait([[UIDevice currentDevice] orientation])) {
        if ([[UIDevice currentDevice] orientation] == UIDeviceOrientationPortrait) {
            cv::transpose(mat, mat);
            CGFloat temp = rect.size.width;
            rect.size.width = rect.size.height;
            rect.size.height = temp;
            cv::flip(mat, mat, 1);
        } else {
            cv::transpose(mat, mat);
            CGFloat temp = rect.size.width;
            rect.size.width = rect.size.height;
            rect.size.height = temp;
            cv::flip(mat, mat, 0);
       }
    } else if (videOrientation == AVCaptureVideoOrientationLandscapeRight && UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation])){
        if ([[UIDevice currentDevice] orientation] == UIDeviceOrientationLandscapeLeft) {
            cv::transpose(mat, mat);
            CGFloat temp = rect.size.width;
            rect.size.width = rect.size.height;
            rect.size.height = temp;
            cv::flip(mat, mat, 1);

            cv::transpose(mat, mat);
            cv::flip(mat, mat, 0);
        } else {
            cv::transpose(mat, mat);
            CGFloat temp = rect.size.width;
            rect.size.width = rect.size.height;
            rect.size.height = temp;
            cv::flip(mat, mat, 1);

            cv::transpose(mat, mat);
            cv::flip(mat, mat, 1);
        }
    }

// TODO доработать для обратной камеры с учетом того что закомпентировано ниже
    // Portrait front
//    cv::transpose(mat, mat);
    
    // PortraitDown front
//    cv::flip(mat, mat, 2);
//    cv::transpose(mat, mat);
//    cv::flip(mat, mat, 2);
    
    //LandscapeRight
//    cv::flip(mat, mat, 2);

    //LandscapeLeft
//    cv::flip(mat, mat, 0);


    videOrientation = AVCaptureVideoOrientationPortrait;
    
    std::vector<cv::Rect> faces;
    
    try {
        _faceCascade.detectMultiScale(mat, faces, 1.1, 2, isSingleFace ? kHaarSingleFaceOptions : kHaarMultieFaceOptions);
    } catch(cv::Exception) {
        
    }
    
    NSMutableArray<NSValue *> *faceRects = [NSMutableArray new];
    
    for (int i = 0; i < faces.size(); i++) {
        [faceRects addObject: [NSValue valueWithCGRect: CGRectMake(faces[i].x, faces[i].y, faces[i].width, faces[i].height)]];
    }
    
    //NSLog(@"faces count = %lu", (unsigned long)faceRects.count);
    
    return faceRects;
}

- (void) detectEyes: (cv::Mat &)mat :(std::vector<cv::Rect>)eyes :(NSString*) cascade_path {
    cv::CascadeClassifier eyes_cascade;
    eyes_cascade.load([cascade_path UTF8String]);
    
    eyes_cascade.detectMultiScale(mat, eyes, 1.20, 5, kHaarFeaturesOptions, cv::Size(30, 30));
    return;
}

- (void) detectNose: (cv::Mat &)mat :(std::vector<cv::Rect>)nose :(NSString*) cascade_path {
    cv::CascadeClassifier nose_cascade;
    nose_cascade.load([cascade_path UTF8String]);
    
    nose_cascade.detectMultiScale(mat, nose, 1.20, 5, kHaarFeaturesOptions, cv::Size(30, 30));
    return;
}

- (void) detectMouth: (cv::Mat &)mat :(std::vector<cv::Rect>)mouth :(NSString*) cascade_path {
    cv::CascadeClassifier mouth_cascade;
    mouth_cascade.load([cascade_path UTF8String]);
    
    mouth_cascade.detectMultiScale(mat, mouth, 1.20, 5, kHaarFeaturesOptions, cv::Size(30, 30));
    return;
}

- (void) detectFacialFeaures: (cv::Mat &)mat :(std::vector<cv::Rect_<int>>)faces :(NSString*) eye_cascade :(NSString*)nose_cascade :(NSString*) mouth_cascade {
    for(unsigned int i = 0; i < faces.size(); ++i) {
        cv::Rect_<int> face = faces[i];
        rectangle(mat, cv::Point(face.x, face.y), cv::Point(face.x+face.width, face.y+face.height), cv::Scalar(255, 0, 0), 1, 4);
        
        cv::Mat ROI = mat(face);
        
        bool is_full_detection = false;
        if( !(eye_cascade.length == 0) && !(nose_cascade.length == 0) && !(mouth_cascade.length == 0) ) {
            is_full_detection = true;
        }
        
        if(eye_cascade.length != 0) {
            std::vector<cv::Rect_<int>> eyes;
            [self detectEyes: ROI :eyes :eye_cascade];
            
            for(unsigned int j = 0; j < eyes.size(); ++j) {
            cv::Rect_<int> e = eyes[j];
                circle(ROI, cv::Point(e.x+e.width/2, e.y+e.height/2), 3, cv::Scalar(0, 255, 0), -1, 8);
            }
        }
        
        double nose_center_height = 0.0;
        if(nose_cascade.length != 0) {
            std::vector<cv::Rect_<int>> nose;
            [self detectNose:ROI :nose :nose_cascade];
            
            for(unsigned int j = 0; j < nose.size(); ++j) {
                cv::Rect_<int> n = nose[j];
                circle(ROI, cv::Point(n.x+n.width/2, n.y+n.height/2), 3, cv::Scalar(0, 255, 0), -1, 8);
                nose_center_height = (n.y + n.height/2);
            }
        }
        
        double mouth_center_height = 0.0;
        if(mouth_cascade.length != 0) {
            std::vector<cv::Rect_<int>> mouth;
            [self detectMouth:ROI :mouth :mouth_cascade];
            
            for(unsigned int j = 0; j < mouth.size(); ++j) {
                cv::Rect_<int> m = mouth[j];
                mouth_center_height = (m.y + m.height/2);
                
                if( (is_full_detection) && (mouth_center_height > nose_center_height) ) {
                    rectangle(ROI, cv::Point(m.x, m.y), cv::Point(m.x+m.width, m.y+m.height), cv::Scalar(0, 255, 0), 1, 4);
                } else if( (is_full_detection) && (mouth_center_height <= nose_center_height) ) {
                    continue;
                } else {
                    rectangle(ROI, cv::Point(m.x, m.y), cv::Point(m.x+m.width, m.y+m.height), cv::Scalar(0, 255, 0), 1, 4);
                }
            }
        }
    }
    return;
}


@end

