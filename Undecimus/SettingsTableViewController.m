//
//  SettingsTableViewController.m
//  Undecimus
//
//  Created by Pwn20wnd on 9/14/18.
//  Copyright © 2018 Pwn20wnd. All rights reserved.
//

#include <sys/utsname.h>
#import "SettingsTableViewController.h"
#include "common.h"
#include "ViewController.h"

@interface SettingsTableViewController ()

@end

@implementation SettingsTableViewController

// https://github.com/Matchstic/ReProvision/blob/7b595c699335940f68702bb204c5aa55b8b1896f/Shared/Application%20Database/RPVApplication.m#L102

- (NSDictionary *)_provisioningProfileAtPath:(NSString *)path {
    NSError *err;
    NSString *stringContent = [NSString stringWithContentsOfFile:path encoding:NSASCIIStringEncoding error:&err];
    stringContent = [stringContent componentsSeparatedByString:@"<plist version=\"1.0\">"][1];
    stringContent = [NSString stringWithFormat:@"%@%@", @"<plist version=\"1.0\">", stringContent];
    stringContent = [stringContent componentsSeparatedByString:@"</plist>"][0];
    stringContent = [NSString stringWithFormat:@"%@%@", stringContent, @"</plist>"];
    
    NSData *stringData = [stringContent dataUsingEncoding:NSASCIIStringEncoding];
    
    NSError *error;
    NSPropertyListFormat format;
    
    id plist = [NSPropertyListSerialization propertyListWithData:stringData options:NSPropertyListImmutable format:&format error:&error];
    
    return plist;
}

#define STATUS_FILE          @"/var/lib/dpkg/status"
#define CYDIA_LIST @"/etc/apt/sources.list.d/cydia.list"

// https://github.com/lechium/nitoTV/blob/53cca06514e79279fa89639ad05b562f7d730079/Classes/packageManagement.m#L1138

+ (NSArray *)dependencyArrayFromString:(NSString *)depends
{
    NSMutableArray *cleanArray = [[NSMutableArray alloc] init];
    NSArray *dependsArray = [depends componentsSeparatedByString:@","];
    for (id depend in dependsArray)
    {
        NSArray *spaceDelimitedArray = [depend componentsSeparatedByString:@" "];
        NSString *isolatedDependency = [[spaceDelimitedArray objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([isolatedDependency length] == 0)
            isolatedDependency = [[spaceDelimitedArray objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        [cleanArray addObject:isolatedDependency];
    }
    
    return cleanArray;
}

// https://github.com/lechium/nitoTV/blob/53cca06514e79279fa89639ad05b562f7d730079/Classes/packageManagement.m#L1163

+ (NSArray *)parsedPackageArray
{
    NSString *packageString = [NSString stringWithContentsOfFile:STATUS_FILE encoding:NSUTF8StringEncoding error:nil];
    NSArray *lineArray = [packageString componentsSeparatedByString:@"\n\n"];
    //NSLog(@"lineArray: %@", lineArray);
    NSMutableArray *mutableList = [[NSMutableArray alloc] init];
    //NSMutableDictionary *mutableDict = [[NSMutableDictionary alloc] init];
    for (id currentItem in lineArray)
    {
        NSArray *packageArray = [currentItem componentsSeparatedByString:@"\n"];
        //    NSLog(@"packageArray: %@", packageArray);
        NSMutableDictionary *currentPackage = [[NSMutableDictionary alloc] init];
        for (id currentLine in packageArray)
        {
            NSArray *itemArray = [currentLine componentsSeparatedByString:@": "];
            if ([itemArray count] >= 2)
            {
                NSString *key = [itemArray objectAtIndex:0];
                NSString *object = [itemArray objectAtIndex:1];
                
                if ([key isEqualToString:@"Depends"]) //process the array
                {
                    NSArray *dependsObject = [SettingsTableViewController dependencyArrayFromString:object];
                    
                    [currentPackage setObject:dependsObject forKey:key];
                    
                } else { //every other key, even if it has an array is treated as a string
                    
                    [currentPackage setObject:object forKey:key];
                }
                
                
            }
        }
        
        //NSLog(@"currentPackage: %@\n\n", currentPackage);
        if ([[currentPackage allKeys] count] > 4)
        {
            //[mutableDict setObject:currentPackage forKey:[currentPackage objectForKey:@"Package"]];
            [mutableList addObject:currentPackage];
        }
        
        currentPackage = nil;
        
    }
    
    NSSortDescriptor *nameDescriptor = [[NSSortDescriptor alloc] initWithKey:@"Name" ascending:YES
                                                                    selector:@selector(localizedCaseInsensitiveCompare:)];
    NSSortDescriptor *packageDescriptor = [[NSSortDescriptor alloc] initWithKey:@"Package" ascending:YES
                                                                       selector:@selector(localizedCaseInsensitiveCompare:)];
    NSArray *descriptors = [NSArray arrayWithObjects:nameDescriptor, packageDescriptor, nil];
    NSArray *sortedArray = [mutableList sortedArrayUsingDescriptors:descriptors];
    
    mutableList = nil;
    
    return sortedArray;
}

// https://github.com/lechium/nitoTV/blob/53cca06514e79279fa89639ad05b562f7d730079/Classes/packageManagement.m#L854

+ (NSString *)domainFromRepoObject:(NSString *)repoObject
{
    //LogSelf;
    if ([repoObject length] == 0)return nil;
    NSArray *sourceObjectArray = [repoObject componentsSeparatedByString:@" "];
    NSString *url = [sourceObjectArray objectAtIndex:1];
    if ([url length] > 7)
    {
        NSString *urlClean = [url substringFromIndex:7];
        NSArray *secondArray = [urlClean componentsSeparatedByString:@"/"];
        return [secondArray objectAtIndex:0];
    }
    return nil;
}

// https://github.com/lechium/nitoTV/blob/53cca06514e79279fa89639ad05b562f7d730079/Classes/packageManagement.m#L869

+ (NSArray *)sourcesFromFile:(NSString *)theSourceFile
{
    NSMutableArray *finalArray = [[NSMutableArray alloc] init];
    NSString *sourceString = [[NSString stringWithContentsOfFile:theSourceFile encoding:NSASCIIStringEncoding error:nil] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *sourceFullArray =  [sourceString componentsSeparatedByString:@"\n"];
    NSEnumerator *sourceEnum = [sourceFullArray objectEnumerator];
    id currentSource = nil;
    while (currentSource = [sourceEnum nextObject])
    {
        NSString *theObject = [SettingsTableViewController domainFromRepoObject:currentSource];
        if (theObject != nil)
        {
            if (![finalArray containsObject:theObject])
                [finalArray addObject:theObject];
        }
    }
    
    return finalArray;
}

+ (NSDictionary *)getDiagnostics {
    struct utsname u = { 0 };
    NSMutableDictionary *md = nil;
    uname(&u);
    md = [[NSMutableDictionary alloc] init];
    md[@"Sysname"] = [NSString stringWithUTF8String:u.sysname];
    md[@"Nodename"] = [NSString stringWithUTF8String:u.nodename];
    md[@"Release"] = [NSString stringWithUTF8String:u.release];
    md[@"Version"] = [NSString stringWithUTF8String:u.version];
    md[@"Machine"] = [NSString stringWithUTF8String:u.machine];
    md[@"ProductVersion"] = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"][@"ProductVersion"];
    md[@"ProductBuildVersion"] = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"][@"ProductBuildVersion"];
    md[@"Sources"] = [SettingsTableViewController sourcesFromFile:CYDIA_LIST];
    md[@"Packages"] = [SettingsTableViewController parsedPackageArray];
    md[@"Preferences"] = [[NSMutableDictionary alloc] init];
    md[@"Preferences"][@"TweakInjection"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_TWEAK_INJECTION];
    md[@"Preferences"][@"LoadDaemons"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_LOAD_DAEMONS];
    md[@"Preferences"][@"DumpAPTicket"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_DUMP_APTICKET];
    md[@"Preferences"][@"RefreshIconCache"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_REFRESH_ICON_CACHE];
    md[@"Preferences"][@"BootNonce"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_BOOT_NONCE];
    md[@"Preferences"][@"Exploit"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_EXPLOIT];
    md[@"Preferences"][@"DisableAutoUpdates"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_DISABLE_AUTO_UPDATES];
    md[@"Preferences"][@"DisableAppRevokes"] = [[NSUserDefaults standardUserDefaults] objectForKey:@K_DISABLE_APP_REVOKES];
    md[@"AppVersion"] = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return md;
}

+ (NSArray *) supportedBuilds {
    NSMutableArray *ma = [[NSMutableArray alloc] init];
    [ma addObject:@"15A5278f"]; // 11.0 beta
    [ma addObject:@"15A5304i"]; // 11.0 beta 2
    [ma addObject:@"15A5304j"]; // 11.0 beta 2
    [ma addObject:@"15A5318g"]; // 11.0 beta 3
    [ma addObject:@"15A5327g"]; // 11.0 beta 4
    [ma addObject:@"15A5341f"]; // 11.0 beta 5
    [ma addObject:@"15A5354b"]; // 11.0 beta 6
    [ma addObject:@"15A5362a"]; // 11.0 beta 7
    [ma addObject:@"15A5368a"]; // 11.0 beta 8
    [ma addObject:@"15A5370a"]; // 11.0 beta 9
    [ma addObject:@"15A5372a"]; // 11.0 beta 10
    [ma addObject:@"15A372"]; // 11.0 GM
    [ma addObject:@"15B5066f"]; // 11.1 beta
    [ma addObject:@"15B5078e"]; // 11.1 beta 2
    [ma addObject:@"15B5086a"]; // 11.1 beta 3
    [ma addObject:@"15B92"]; // 11.1 beta 4
    [ma addObject:@"15B93"]; // 11.1 beta 5
    [ma addObject:@"15C5092b"]; // 11.2 beta
    [ma addObject:@"15C5097d"]; // 11.2 beta 2
    [ma addObject:@"15C5107a"]; // 11.2 beta 3
    [ma addObject:@"15C5110b"]; // 11.2 beta 4
    [ma addObject:@"15C5111a"]; // 11.2 beta 5
    [ma addObject:@"15C114"]; // 11.2 beta 6
    [ma addObject:@"15D5037e"]; // 11.2.5 beta
    [ma addObject:@"15D5046b"]; // 11.2.5 beta 2
    [ma addObject:@"15D5049a"]; // 11.2.5 beta 3
    [ma addObject:@"15D5054a"]; // 11.2.5 beta 4
    [ma addObject:@"15D5057a"]; // 11.2.5 beta 5
    [ma addObject:@"15D5059a"]; // 11.2.5 beta 6
    [ma addObject:@"15D60"]; // 11.2.5 beta 7
    [ma addObject:@"15E5167f"]; // 11.3 beta
    [ma addObject:@"15E5178f"]; // 11.3 beta 2
    [ma addObject:@"15E5189f"]; // 11.3 beta 3
    [ma addObject:@"15E5201e"]; // 11.3 beta 4
    [ma addObject:@"15E5211a"]; // 11.3 beta 5
    [ma addObject:@"15E5216a"]; // 11.3 beta 6
    [ma addObject:@"15F5037c"]; // 11.4 beta
    [ma addObject:@"15F5049c"]; // 11.4 beta 2
    [ma addObject:@"15F5061d"]; // 11.4 beta 3
    [ma addObject:@"15A372"]; // 11.0
    [ma addObject:@"15A402"]; // 11.0.1
    [ma addObject:@"15A421"]; // 11.0.2
    [ma addObject:@"15A432"]; // 11.0.3
    [ma addObject:@"15B93"]; // 11.1
    [ma addObject:@"15B150"]; // 11.1.1
    [ma addObject:@"15B202"]; // 11.1.2
    [ma addObject:@"15C114"]; // 11.2
    [ma addObject:@"15C153"]; // 11.2.1
    [ma addObject:@"15C202"]; // 11.2.2
    [ma addObject:@"15D60"]; // 11.2.5
    [ma addObject:@"15D100"]; // 11.2.6
    [ma addObject:@"15E216"]; // 11.3
    [ma addObject:@"15E302"]; // 11.3.1
    return ma;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIImageView *myImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Clouds"]];
    [myImageView setContentMode:UIViewContentModeScaleAspectFill];
    [myImageView setFrame:self.tableView.frame];
    UIView *myView = [[UIView alloc] initWithFrame:myImageView.frame];
    [myView setBackgroundColor:[UIColor whiteColor]];
    [myView setAlpha:0.84];
    [myView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [myImageView addSubview:myView];
    [self.tableView setBackgroundView:myImageView];
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    [self.navigationController.navigationBar setShadowImage:[UIImage new]];
    [self.BootNonceTextField setDelegate:self];
    self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(userTappedAnyware:)];
    self.tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:self.tap];
    [self reloadData];
}

- (void)userTappedAnyware:(UITapGestureRecognizer *) sender
{
    [self.view endEditing:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)reloadData {
    [self.TweakInjectionSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_TWEAK_INJECTION]];
    [self.LoadDaemonsSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_LOAD_DAEMONS]];
    [self.DumpAPTicketSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_DUMP_APTICKET]];
    [self.BootNonceTextField setPlaceholder:[[NSUserDefaults standardUserDefaults] objectForKey:@K_BOOT_NONCE]];
    [self.BootNonceTextField setText:nil];
    [self.RefreshIconCacheSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_REFRESH_ICON_CACHE]];
    [self.KernelExploitSegmentedControl setSelectedSegmentIndex:[[NSUserDefaults standardUserDefaults] integerForKey:@K_EXPLOIT]];
    [self.DisableAutoUpdatesSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_DISABLE_AUTO_UPDATES]];
    [self.DisableAppRevokesSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_DISABLE_APP_REVOKES]];
    [self.KernelExploitSegmentedControl setEnabled:[[self _provisioningProfileAtPath:[[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"]][@"Entitlements"][@"com.apple.developer.networking.multipath"] boolValue] forSegmentAtIndex:1];
    [self.KernelExploitSegmentedControl setEnabled:([[[NSMutableDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"][@"ProductBuildVersion"] rangeOfString:@"15A"].location != NSNotFound || [[[NSMutableDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"][@"ProductBuildVersion"] rangeOfString:@"15B"].location != NSNotFound) forSegmentAtIndex:2];
    [self.OpenCydiaButton setEnabled:[[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"cydia://"]]];
    [self.ExpiryLabel setPlaceholder:[NSString stringWithFormat:@"%d Days", (int)[[self _provisioningProfileAtPath:[[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"]][@"ExpirationDate"] timeIntervalSinceDate:[NSDate date]] / 86400]];
    [self.OverwriteBootNonceSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@K_OVERWRITE_BOOT_NONCE]];
    [self.tableView reloadData];
}

- (IBAction)TweakInjectionSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.TweakInjectionSwitch isOn] forKey:@K_TWEAK_INJECTION];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}
- (IBAction)LoadDaemonsSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.LoadDaemonsSwitch isOn] forKey:@K_LOAD_DAEMONS];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}
- (IBAction)DumpAPTicketSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.DumpAPTicketSwitch isOn] forKey:@K_DUMP_APTICKET];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}

- (IBAction)BootNonceTextFieldTriggered:(id)sender {
    uint64_t val = 0;
    if ([[NSScanner scannerWithString:[self.BootNonceTextField text]] scanHexLongLong:&val] && val != HUGE_VAL && val != -HUGE_VAL) {
        [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@ADDR, val] forKey:@K_BOOT_NONCE];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } else {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Invalid Entry" message:@"The boot nonce entered could not be parsed" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *OK = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alertController addAction:OK];
        [self presentViewController:alertController animated:YES completion:nil];
    }
    [self reloadData];
}

- (IBAction)RefreshIconCacheSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.RefreshIconCacheSwitch isOn] forKey:@K_REFRESH_ICON_CACHE];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}
- (IBAction)KernelExploitSegmentedControl:(id)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:self.KernelExploitSegmentedControl.selectedSegmentIndex forKey:@K_EXPLOIT];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}

- (IBAction)DisableAppRevokesSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.DisableAppRevokesSwitch isOn] forKey:@K_DISABLE_APP_REVOKES];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}

extern void iosurface_die(void);
extern int vfs_die(void);
extern int mptcp_die(void);

- (IBAction)tappedOnRestart:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul), ^{
        NOTICE("The device will be restarted.", 1);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.restartButton setEnabled:NO];
            [self.restartButton setTitle:@"Restarting..." forState:UIControlStateDisabled];
        });
        iosurface_die();
        vfs_die();
        mptcp_die();
        sleep(2);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.restartButton setTitle:@"Failed to restart." forState:UIControlStateDisabled];
        });
    });
}

- (IBAction)DisableAutoUpdatesSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.DisableAutoUpdatesSwitch isOn] forKey:@K_DISABLE_AUTO_UPDATES];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}

- (IBAction)tappedOnShareDiagnosticsData:(id)sender {
    NSURL *URL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/Documents/diagnostics.plist", NSHomeDirectory()]];
    [[SettingsTableViewController getDiagnostics] writeToURL:URL error:nil];
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[URL] applicationActivities:nil];
    if ([activityViewController respondsToSelector:@selector(popoverPresentationController)]) {
        [[activityViewController popoverPresentationController] setSourceView:self.ShareDiagnosticsDataButton];
    }
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (IBAction)tappedOnOpenCydia:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://"] options:@{} completionHandler:nil];
}
- (IBAction)OverwriteBootNonceSwitchTriggered:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[self.OverwriteBootNonceSwitch isOn] forKey:@K_OVERWRITE_BOOT_NONCE];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end