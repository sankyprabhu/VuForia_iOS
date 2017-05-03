/*===============================================================================
 Copyright (c) 2016 PTC Inc. All Rights Reserved. Confidential and Proprietary -
 Protected under copyright and other laws.
 Vuforia is a trademark of PTC Inc., registered in the United States and other
 countries.
 ===============================================================================*/

#import <UIKit/UIKit.h>

@interface SampleAppAboutViewController : UIViewController <UIWebViewDelegate>
@property (weak, nonatomic) IBOutlet UIWebView *uiWebView;

@property (nonatomic, copy) NSString * appTitle;
@property (nonatomic, copy) NSString * appAboutPageName;

@end
