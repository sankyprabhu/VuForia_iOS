/*===============================================================================
 Copyright (c) 2015-2016 PTC Inc. All Rights Reserved. Confidential and Proprietary -
 Protected under copyright and other laws.
 Vuforia is a trademark of PTC Inc., registered in the United States and other
 countries.
 ===============================================================================*/

#import <UIKit/UIKit.h>
#import "ImageTargetsMetalView.h"
#import "SampleApplicationSession.h"
#import "SampleAppMenuViewController.h"
#import <Vuforia/DataSet.h>

@interface ImageTargetsMetalViewController : UIViewController <SampleApplicationControl, SampleAppMenuDelegate> {
    
    Vuforia::DataSet*  dataSetCurrent;
    Vuforia::DataSet*  dataSetTarmac;
    Vuforia::DataSet*  dataSetStonesAndChips;
}

@property (nonatomic, strong) ImageTargetsMetalView * metalView;
@property (nonatomic, strong) UITapGestureRecognizer * tapGestureRecognizer;
@property (nonatomic, strong) SampleApplicationSession * vapp;

@property (nonatomic, readwrite) BOOL showingMenu;

@end
