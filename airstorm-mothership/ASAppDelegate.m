//
//  ASAppDelegate.m
//  airstorm-mothership
//
//  Created by Acsa Lu on 6/21/13.
//  Copyright (c) 2013 com.nmlab-g7. All rights reserved.
//

#import "ASAppDelegate.h"
#import <ParseOSX/Parse.h>

@implementation ASAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [Parse setApplicationId:@"n7N5WY2FgddzT9GagvvgEgNFYR4u2iRjP4CkCKK3"
                  clientKey:@"YzqN7TkJitqR9N2bCyfiaHyeJ4hM8ovEOoE69le7"];
    
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    _locationManager.delegate = self;
    [_locationManager startUpdatingLocation];
}

- (IBAction)runButtonPressed:(id)sender
{
    [self detectMarkerId:_markerId.intValue];
}

#pragma mark - Marker Detection methods

- (void)detectMarkerId:(int)markerId
{
    PFQuery *query = [PFQuery queryWithClassName:@"PlayBack"];
    
    [query whereKey:@"markerId" equalTo:@(markerId)];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            if (objects.count == 0) {
                NSLog(@"no video set");
                [self showNotAssignedWarningForplayVideoForWebView:_webView];
            } else {
                NSLog(@"videoId: %@", objects[0][@"videoId"]);
                [self playVideoForplayVideoForWebView:_webView withVideoId:objects[0][@"videoId"]];
            }
        } else {
            NSLog(@"Error: %@", error);
        }
    }];
}


#pragma mark - Content Displaying methods

- (void)showNotAssignedWarningForplayVideoForWebView:(WebView *)webView
{
    [webView.mainFrame loadHTMLString:@"NO MEDIA ASSIGNED YET!" baseURL:nil];
}

- (void)createDisplayWithFrame:(CGRect)frame
{
    
}


- (void)playVideoForplayVideoForWebView:(WebView *)webView withVideoId:(NSString *)videoId
{
    NSString *ytHTML = [NSString stringWithFormat:@"\
                        <iframe width='%f' height='%f'\
                        src='http://www.youtube.com/embed/%@'></iframe>", webView.frame.size.width, webView.frame.size.height, videoId];
    
    
    [webView.mainFrame loadHTMLString:ytHTML baseURL:nil];
}

#pragma mark - CLLocationManagerDelegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    NSLog(@"%@", newLocation);
    NSLog(@"moving %f m", [newLocation distanceFromLocation:oldLocation]);
    _currentLocation = newLocation;
}

@end
