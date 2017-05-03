/*===============================================================================
 Copyright (c) 2016 PTC Inc. All Rights Reserved. Confidential and Proprietary -
 Protected under copyright and other laws.
 Vuforia is a trademark of PTC Inc., registered in the United States and other
 countries.
 ===============================================================================*/

#import "SampleAppAboutViewController.h"

@interface SampleAppAboutViewController ()

@end

@implementation SampleAppAboutViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self loadWebView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(dismissAppController:)
                                                 name:@"kDismissAppViewController"
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // We ensure the navigation bar is shown
    [self.navigationController setNavigationBarHidden:NO animated:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    [self setUiWebView:nil];
}

- (IBAction)onStartButton:(id)sender
{
    // based on the state of the switch, we decide which segue to use
    [self performSegueWithIdentifier:@"PushImageTargets" sender:self];
}

//------------------------------------------------------------------------------
#pragma mark - Autorotation
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate {
    return YES;
}

//------------------------------------------------------------------------------
#pragma mark - Private

- (void) dismissAppController:(id) sender
{
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)loadWebView
{
    self.uiWebView.delegate = self;
    
    //  Load html from a local file for the about screen
    NSString *aboutFilePath = [[NSBundle mainBundle] pathForResource:@"IT_about"
                                                              ofType:@"html"];
    
    NSString* htmlString = [NSString stringWithContentsOfFile:aboutFilePath
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
    
    NSString *aPath = [[NSBundle mainBundle] bundlePath];
    NSURL *anURL = [NSURL fileURLWithPath:aPath];
    [self.uiWebView loadHTMLString:htmlString baseURL:anURL];
}


//------------------------------------------------------------------------------
#pragma mark - UIWebViewDelegate

-(BOOL) webView:(UIWebView *)inWeb shouldStartLoadWithRequest:(NSURLRequest *)inRequest navigationType:(UIWebViewNavigationType)inType
{
    //  Opens the links within this UIWebView on a safari web browser
    
    BOOL retVal = NO;
    
    if ( inType == UIWebViewNavigationTypeLinkClicked )
    {
        [[UIApplication sharedApplication] openURL:[inRequest URL]];
    }
    else
    {
        retVal = YES;
    }
    
    return retVal;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    // Uncomment to have the double finger tap show the build number
//    UITapGestureRecognizer *gesture = [[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(handleTouches:)] autorelease];
//    gesture.numberOfTouchesRequired = 2;
//    [webView addGestureRecognizer:gesture];
}

- (void) handleTouches:(UILongPressGestureRecognizer *)gesture {
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Application Version Number"
                                                    message:[NSString stringWithFormat:@"Build number is: %@", version]
                                                    delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    
}

@end
