//
//  ASMarkerDetector.m
//  airstorm-mothership
//
//  Created by LCR on 6/22/13.
//  Copyright (c) 2013 com.nmlab-g7. All rights reserved.
//

#import "ASMarkerDetector.h"
#import "ASAppDelegate.h"
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

@implementation ASMarkerDetector

+ (void)detect
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
            return;
        }
        
        CvCapture* capture = 0;
        Mat frame, frameCopy, image;
        
        capture = cvCaptureFromCAM( 0 ); //0=default, -1=any camera, 1..99=your camera
        if(!capture) cout << "No camera detected" << endl;
        
        cvNamedWindow( "Marker Detector", 1 );
        
        if( capture )
        {
            ASAppDelegate* appDelegate = ((ASAppDelegate *)[NSApp delegate]);
            
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
                
                cameraResolutionWidth = InImage.cols;
                cameraResolutionHeight = InImage.rows;
                
                //Ok, let's detect
                MDetector.detect(InImage,Markers,CamParam,MarkerSize);
                //for each marker, draw info and its boundaries in the image
//                cout<<"size:"<<Markers.size()<<endl;
                
                for (unsigned int i=0;i<Markers.size();i++) {
                    aruco::Marker marker = Markers[i];
                    marker.draw(InImage,Scalar(0,0,255),2);
                    
                    if (marker.id == 0) {
                        cv::Point2f p = centerOfMarker(marker);
                        appDelegate.corner_lt = CGPointMake(p.x, p.y);
                        continue;
                    } else if (marker.id == 1) {
                        cv::Point2f p = centerOfMarker(marker);
                        appDelegate.corner_rt = CGPointMake(p.x, p.y);
                        continue;
                    } else if (marker.id == 2) {
                        cv::Point2f p = centerOfMarker(marker);
                        appDelegate.corner_rb = CGPointMake(p.x, p.y);
                        continue;
                    } else if (marker.id == 3) {
                        cv::Point2f p = centerOfMarker(marker);
                        appDelegate.corner_lb = CGPointMake(p.x, p.y);
                        continue;
                    }
                    
                    cout << "Detecte marker , marker ID: " << marker.id << endl;
                    
                    cv::Point2f p = centerOfMarker(marker);
                    
                    [appDelegate detectMarkerId:marker.id atAbsPosition:CGPointMake(p.x, p.y)];
                }
                //                //draw a 3d cube in each marker if there is 3d info
                if (  CamParam.isValid() && MarkerSize!=-1) {
                    for (unsigned int i=0;i<Markers.size();i++) {
                        CvDrawingUtils::draw3dCube(InImage,Markers[i],CamParam);
                    }
                }
                cv::imshow("Marker Detector",InImage);
            }
            
            waitKey(0);
            
            cvDestroyWindow("Marker Detector");
            
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

cv::Point2f centerOfMarker(aruco::Marker marker)
{
    float x = marker[0].x + marker[1].x + marker[2].x + marker[3].x;
    float y = marker[0].y + marker[1].y + marker[2].y + marker[3].y;
    return cv::Point2f(x/4, y/4);
}


@end
