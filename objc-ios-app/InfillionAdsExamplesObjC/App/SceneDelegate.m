#import "SceneDelegate.h"

#import "HomeViewController.h"
#import "Theme.h"

@implementation SceneDelegate

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }
    UINavigationController *navigationController =
        [[UINavigationController alloc] initWithRootViewController:[[HomeViewController alloc] init]];
    [Theme styleNavigationBar:navigationController.navigationBar];

    UIWindow *window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    window.rootViewController = navigationController;
    window.tintColor = Theme.bloomPink;
    [window makeKeyAndVisible];
    self.window = window;
}

@end
