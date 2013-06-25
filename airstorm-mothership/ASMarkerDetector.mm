//
//  ASMarkerDetector.m
//  airstorm-mothership
//
//  Created by LCR on 6/22/13.
//  Copyright (c) 2013 com.nmlab-g7. All rights reserved.
//

#import "ASMarkerDetector.h"
#import "ASAppDelegate.h"
#import "ASCVUtility.h"
#include <iostream>
#include <opencv2/opencv.hpp>
#include "aruco.h"
#include "arucofidmarkers.h"
#include <vector>


using namespace std;
using namespace cv;
using namespace aruco;

static int cameraResolutionWidth = 0;
static int cameraResolutionHeight = 0;

static const int avg_cb = 120;
static const int avg_cr = 155;
static const int SkinRange = 22;

@implementation ASMarkerDetector

+ (ASMarkerDetector *)sharedDetector
{
    static ASMarkerDetector *sharedDetector;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDetector = [[self alloc] init];
    });
    return sharedDetector;
}

- (void)detect
{
    try
    {
        aruco::CameraParameters CamParam;
        MarkerDetector MDetector;
        vector<aruco::Marker> Markers;
        float MarkerSize=0.1;
        
        try {
            CamParam.readFromXMLFile("/tmp/airtorm-camarea-calibration.yml");
        } catch (cv::Exception) {
            NSAlert *alert = [NSAlert alertWithMessageText:@"Calibration file not found" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Please calibrate first."];
            [alert beginSheetModalForWindow:nil modalDelegate:nil didEndSelector:nil contextInfo:nil];
            [ASCVUtility calibrate];
        }
        
        CvCapture* capture = 0;
        Mat frame, frameCopy, image;
        
        capture = cvCaptureFromCAM( 0 ); //0=default, -1=any camera, 1..99=your camera
        if(!capture) cout << "No camera detected" << endl;

        cvNamedWindow( "Capture", 1 );
        cvNamedWindow( "Skin", 1);

        cameraResolutionWidth = cvGetCaptureProperty(capture, CV_CAP_PROP_FRAME_WIDTH);
        cameraResolutionHeight = cvGetCaptureProperty(capture, CV_CAP_PROP_FRAME_HEIGHT);
        DefaultMediaFrameSize.width = cameraResolutionWidth / 6;
        DefaultMediaFrameSize.height = cameraResolutionHeight / 6;
        
        if( capture )
        {
            cout << "In capture ..." << endl;
            
            for(;;)
            {
                IplImage* iplImg = cvQueryFrame( capture );
                frame = iplImg;
                if( frame.empty() )
                    break;
                if( iplImg->origin == IPL_ORIGIN_TL )
                    frame.copyTo( frameCopy );
                else
                    flip( frame, frameCopy, 0 );
                
                if( waitKey( 10 ) >= 0 )
                    cvReleaseCapture( &capture );
                
                cv::Mat InImage(frame);
            
                // variable for skin detection 
                IplImage* pImgCopy = cvCreateImage(cvGetSize(iplImg), iplImg->depth, iplImg->nChannels);
                cvCopy(iplImg, pImgCopy);
                RGBtoYCbCr(pImgCopy);
                SkinColorDetection(pImgCopy);
                
                IplImage *im_gray = cvCreateImage(cvGetSize(pImgCopy),IPL_DEPTH_8U,1);
                cvCvtColor(pImgCopy, im_gray, CV_RGB2GRAY);
                
                Mat mat_gray(im_gray,0);
                Mat mat_bw  = mat_gray > 128;
                
                // Ok, let's detect marker
                MDetector.detect(InImage,Markers,CamParam,MarkerSize);
                
                for (unsigned int i=0; i<Markers.size(); i++) {
                    aruco::Marker marker = Markers[i];
                    //for each marker, draw info and its boundaries in the image
                    marker.draw(InImage, Scalar(0, 0, 255), 2);
                    //draw a 3d cube in each marker if there is 3d info
                    CvDrawingUtils::draw3dCube(InImage, marker, CamParam);
                    
                    CGPoint markerCenter = [self centerOfMarkerInCGPoint:marker];
                    
                    if (marker.id == 0) {
                        [_delegate setCornerLeftTop:markerCenter];
                        continue;
                    } else if (marker.id == 1) {
                        [_delegate setCornerRightTop:markerCenter];
                        continue;
                    } else if (marker.id == 2) {
                        [_delegate setCornerRightBottom:markerCenter];
                        continue;
                    } else if (marker.id == 3) {
                        [_delegate setCornerLeftBottom:markerCenter];
                        continue;
                    }
                    
                    cout << "Detecte marker , marker ID: " << marker.id
                         << "at x:" << markerCenter.x << "  y:" << markerCenter.y << endl;
                    
                    CGPoint mediaFrameOrigin = [self frameLeftBottomPointOfMarker:marker];
                    [_delegate detectMarkerId:marker.id atAbsPosition:mediaFrameOrigin];
                    
                    // skin detection
                    NSRect nsRect = [_delegate getFrameOfMarker:@(marker.id)];
                    if (nsRect.origin.x == -1000) continue;
                    
                    cv::Rect cvRect = nsRectToCVRect(nsRect);
                    
                    float ratio= [_delegate scaleRatioOfProjection];
                    cv::Rect roiRect = cv::Rect(mediaFrameOrigin.x + 
                                                (DefaultMediaFrameSize.width/2 - DefaultMediaFrameSize.width/10),
                                                cameraResolutionHeight - 
                                                (mediaFrameOrigin.y + (DefaultMediaFrameSize.height/2 + DefaultMediaFrameSize.height/10)),
                                                DefaultMediaFrameSize.width/4,
                                                DefaultMediaFrameSize.height/4);
                    cv::Mat roiImg = mat_bw(roiRect);
                    
                    cv::Rect redRect = cv::Rect(markerCenter.x + (DefaultMediaFrameSize.width/2 - DefaultMediaFrameSize.width/10),
                                                markerCenter.y + (DefaultMediaFrameSize.height/2 + DefaultMediaFrameSize.height/10),
                                                40, 40);
                    cvRectangleR(pImgCopy, roiRect, Scalar(0,0,250));
                    
                    double count = 0;
                    MatIterator_<uchar> it, end;
                    for( it = roiImg.begin<uchar>(), end = roiImg.end<uchar>(); it != end; ++it) {
                        if(*(it) > 0){
                            count++;
                        }
                        
                        if (count > 0.5*roiImg.rows*roiImg.cols) {
                            [_delegate markerIsPressed:@(marker.id)];
                            break;
                        }
                    }
                
                }
            
                cv::imshow("Capture",InImage);
                cvShowImage("Skin", pImgCopy);
            }
            
            waitKey(0);
            
            cvDestroyWindow("Capture");
            cvDestroyWindow("Skin");
            
        }
        
    }
    
    catch (std::exception &ex)
    {
        cout << "Exception :" << ex.what() << endl;
    }
    
}

+ (int)cameraResolutionWidth
{
    return cameraResolutionWidth;
}

+ (int)cameraResolutionHeight
{
    return cameraResolutionHeight;
}

- (CGPoint)centerOfMarkerInCGPoint:(aruco::Marker)marker
{
    float x = marker[0].x + marker[1].x + marker[2].x + marker[3].x;
    float y = marker[0].y + marker[1].y + marker[2].y + marker[3].y;

    return CGPointMake(x/4, cameraResolutionHeight - y/4);
}

- (CGPoint)frameLeftBottomPointOfMarker:(aruco::Marker)marker
{
    float x = (marker[0].x + marker[1].x + marker[2].x + marker[3].x) / 4;
    float y = cameraResolutionHeight - ((marker[0].y + marker[1].y + marker[2].y + marker[3].y) / 4);
    float offset_x = (ABS(marker[0].x - marker[2].x) + ABS(marker[1].x - marker[3].x)) / 4;
    float offset_y = (ABS(marker[0].y - marker[2].y) + ABS(marker[1].y - marker[3].y)) / 4;
    
    return CGPointMake(x + offset_x, y + offset_y);
}

cv::Rect nsRectToCVRect(NSRect nsRect)
{
    return cv::Rect(nsRect.origin.x, cameraResolutionHeight - nsRect.origin.y, nsRect.size.width, nsRect.size.height);
}

void RGBtoYCbCr(IplImage *image)
{
    CvScalar scalarImg;
    double cb, cr, y;
    for(int i=0; i<image->height; i++)
        for(int j=0; j<image->width; j++)
        {
            scalarImg = cvGet2D(image, i, j); // get RGB value from image
            y =  (16 + scalarImg.val[2]*0.257 + scalarImg.val[1]*0.504
                  + scalarImg.val[0]*0.098);
            cb = (128 - scalarImg.val[2]*0.148 - scalarImg.val[1]*0.291
                  + scalarImg.val[0]*0.439);
            cr = (128 + scalarImg.val[2]*0.439 - scalarImg.val[1]*0.368
                  - scalarImg.val[0]*0.071);
            // change color space from RGB to YCbCr
            cvSet2D(image, i, j, cvScalar( y, cr, cb));
        }
}


void SkinColorDetection(IplImage *image)
{
    CvScalar scalarImg;
    double cb, cr;
    for(int i=0; i<image->height; i++)
        for(int j=0; j<image->width; j++)
        {
            scalarImg = cvGet2D(image, i, j);
            cr = scalarImg.val[1];
            cb = scalarImg.val[2];
            if((cb > avg_cb-SkinRange && cb < avg_cb+SkinRange) &&
               (cr > avg_cr-SkinRange && cr < avg_cr+SkinRange))
                cvSet2D(image, i, j, cvScalar( 255, 255, 255));
            else
                cvSet2D(image, i, j, cvScalar( 0, 0, 0));
        }
}



@end

