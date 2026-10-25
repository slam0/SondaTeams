#import "AppDelegate.h"
#import "TPController.h"
#import "TPCrash.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    TPCrashInstall();
    NSString *last = TPTakeLastRunReport();
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    TPController *c = [[TPController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:c];
    nav.navigationBar.barStyle = UIBarStyleBlack;
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    if (last) {
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Poprzednie uruchomienie"
                                                    message:last delegate:nil
                                          cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [a show];
    }
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    TPCrumbCleanExit();
}

@end
