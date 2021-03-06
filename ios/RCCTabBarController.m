#import "RCCTabBarController.h"
#import "RCCViewController.h"
#import <React/RCTConvert.h>
#import "RCCManager.h"
#import "RCTHelpers.h"
#import <React/RCTUIManager.h>
#import "UIViewController+Rotation.h"
#import "RCCEventEmitter.h"

@interface RCTUIManager ()

- (void)configureNextLayoutAnimation:(NSDictionary *)config
                        withCallback:(RCTResponseSenderBlock)callback
                       errorCallback:(__unused RCTResponseSenderBlock)errorCallback;

@end

@interface RCCTabBarController ()

// 用来放置自定义的小badge组件
@property (nonatomic,strong) NSMutableArray *dotArr;
// 用来发送通知
@property (nonatomic,strong) RCCEventEmitter *emitter;

@end

@implementation RCCTabBarController


-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
  return [self supportedControllerOrientations];
}

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
  id queue = [[RCCManager sharedInstance].getBridge uiManager].methodQueue;
  dispatch_async(queue, ^{
    [[[RCCManager sharedInstance].getBridge uiManager] configureNextLayoutAnimation:nil withCallback:^(NSArray* arr){} errorCallback:^(NSArray* arr){}];
  });
  
  if (tabBarController.selectedIndex != [tabBarController.viewControllers indexOfObject:viewController]) {
    NSDictionary *body = @{
                           @"selectedTabIndex": @([tabBarController.viewControllers indexOfObject:viewController]),
                           @"unselectedTabIndex": @(tabBarController.selectedIndex)
                           };
    [RCCTabBarController sendScreenTabChangedEvent:viewController body:body];
    
    [[[RCCManager sharedInstance] getBridge].eventDispatcher sendAppEventWithName:@"bottomTabSelected" body:body];
    if ([viewController isKindOfClass:[UINavigationController class]]) {
      UINavigationController *navigationController = (UINavigationController*)viewController;
      UIViewController *topViewController = navigationController.topViewController;
      
      if ([topViewController isKindOfClass:[RCCViewController class]]) {
        RCCViewController *topRCCViewController = (RCCViewController*)topViewController;
        topRCCViewController.commandType = COMMAND_TYPE_BOTTOME_TAB_SELECTED;
        topRCCViewController.timestamp = [RCTHelpers getTimestampString];
      }
    }
    
  } else {
    [RCCTabBarController sendScreenTabPressedEvent:viewController body:nil];
  }
  
  
  
  return YES;
}

- (UIImage *)image:(UIImage*)image withColor:(UIColor *)color1
{
  UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextTranslateCTM(context, 0, image.size.height);
  CGContextScaleCTM(context, 1.0, -1.0);
  CGContextSetBlendMode(context, kCGBlendModeNormal);
  CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
  CGContextClipToMask(context, rect, image.CGImage);
  [color1 setFill];
  CGContextFillRect(context, rect);
  UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return newImage;
}

- (instancetype)initWithProps:(NSDictionary *)props children:(NSArray *)children globalProps:(NSDictionary*)globalProps bridge:(RCTBridge *)bridge
{
  self = [super init];
  if (!self) return nil;
  
  [self initializeDotArrWithTotalCount:children.count];
  
  self.delegate = self;
  
  self.tabBar.translucent = YES; // default
  
  UIColor *buttonColor = nil;
  UIColor *selectedButtonColor = nil;
  UIColor *labelColor = nil;
  UIColor *selectedLabelColor = nil;
  NSDictionary *tabsStyle = props[@"style"];
  if (tabsStyle)
  {
    NSString *tabBarButtonColor = tabsStyle[@"tabBarButtonColor"];
    if (tabBarButtonColor)
    {
      UIColor *color = tabBarButtonColor != (id)[NSNull null] ? [RCTConvert UIColor:tabBarButtonColor] : nil;
      self.tabBar.tintColor = color;
      buttonColor = color;
      selectedButtonColor = color;
    }
    NSString *tabBarSelectedButtonColor = tabsStyle[@"tabBarSelectedButtonColor"];
    if (tabBarSelectedButtonColor)
    {
      UIColor *color = tabBarSelectedButtonColor != (id)[NSNull null] ? [RCTConvert UIColor:tabBarSelectedButtonColor] : nil;
      self.tabBar.tintColor = color;
      selectedButtonColor = color;
    }
    NSString *tabBarLabelColor = tabsStyle[@"tabBarLabelColor"];
    if(tabBarLabelColor) {
      UIColor *color = tabBarLabelColor != (id)[NSNull null] ? [RCTConvert UIColor:tabBarLabelColor] : nil;
      labelColor = color;
    }
    NSString *tabBarSelectedLabelColor = tabsStyle[@"tabBarSelectedLabelColor"];
    if(tabBarLabelColor) {
      UIColor *color = tabBarSelectedLabelColor != (id)[NSNull null] ? [RCTConvert UIColor:
                                                                        tabBarSelectedLabelColor] : nil;
      selectedLabelColor = color;
    }
    NSString *tabBarBackgroundColor = tabsStyle[@"tabBarBackgroundColor"];
    if (tabBarBackgroundColor)
    {
      UIColor *color = tabBarBackgroundColor != (id)[NSNull null] ? [RCTConvert UIColor:tabBarBackgroundColor] : nil;
      self.tabBar.barTintColor = color;
    }
    
    NSString *tabBarTranslucent = tabsStyle[@"tabBarTranslucent"];
    if (tabBarTranslucent)
    {
      self.tabBar.translucent = [tabBarTranslucent boolValue] ? YES : NO;
    }
    
    NSString *tabBarHideShadow = tabsStyle[@"tabBarHideShadow"];
    if (tabBarHideShadow)
    {
      self.tabBar.clipsToBounds = [tabBarHideShadow boolValue] ? YES : NO;
    }
  }
  
  NSMutableArray *viewControllers = [NSMutableArray array];
  
  // go over all the tab bar items
  for (NSDictionary *tabItemLayout in children)
  {
    // make sure the layout is valid
    if (![tabItemLayout[@"type"] isEqualToString:@"TabBarControllerIOS.Item"]) continue;
    if (!tabItemLayout[@"props"]) continue;
    
    // get the view controller inside
    if (!tabItemLayout[@"children"]) continue;
    if (![tabItemLayout[@"children"] isKindOfClass:[NSArray class]]) continue;
    if ([tabItemLayout[@"children"] count] < 1) continue;
    NSDictionary *childLayout = tabItemLayout[@"children"][0];
    UIViewController *viewController = [RCCViewController controllerWithLayout:childLayout globalProps:globalProps bridge:bridge];
    if (!viewController) continue;
    
    // create the tab icon and title
    NSString *title = tabItemLayout[@"props"][@"title"];
    UIImage *iconImage = nil;
    id icon = tabItemLayout[@"props"][@"icon"];
    if (icon)
    {
//      wws: fix 使用selected 图片原始样式
      iconImage = [[RCTConvert UIImage: icon] imageWithRenderingMode: UIImageRenderingModeAlwaysOriginal];
//      iconImage = [RCTConvert UIImage:icon];
      
      if (buttonColor)
      {
        iconImage = [[self image:iconImage withColor:buttonColor] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
      }
    }
    UIImage *iconImageSelected = nil;
    id selectedIcon = tabItemLayout[@"props"][@"selectedIcon"];
    if (selectedIcon) {
//       wws: fix 使用selected 图片原始样式
      iconImageSelected = [[RCTConvert UIImage: selectedIcon] imageWithRenderingMode: UIImageRenderingModeAlwaysOriginal];
//      iconImageSelected = [RCTConvert UIImage:selectedIcon];
    } else {
      iconImageSelected = [RCTConvert UIImage:icon];
    }
    
    viewController.tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:iconImage tag:0];
    viewController.tabBarItem.accessibilityIdentifier = tabItemLayout[@"props"][@"testID"];
    viewController.tabBarItem.selectedImage = iconImageSelected;
    
    id imageInsets = tabItemLayout[@"props"][@"iconInsets"];
    if (imageInsets && imageInsets != (id)[NSNull null])
    {
      id topInset = imageInsets[@"top"];
      id leftInset = imageInsets[@"left"];
      id bottomInset = imageInsets[@"bottom"];
      id rightInset = imageInsets[@"right"];
      
      CGFloat top = topInset != (id)[NSNull null] ? [RCTConvert CGFloat:topInset] : 0;
      CGFloat left = topInset != (id)[NSNull null] ? [RCTConvert CGFloat:leftInset] : 0;
      CGFloat bottom = topInset != (id)[NSNull null] ? [RCTConvert CGFloat:bottomInset] : 0;
      CGFloat right = topInset != (id)[NSNull null] ? [RCTConvert CGFloat:rightInset] : 0;
      
      viewController.tabBarItem.imageInsets = UIEdgeInsetsMake(top, left, bottom, right);
    }
    NSMutableDictionary *unselectedAttributes = [RCTHelpers textAttributesFromDictionary:tabsStyle withPrefix:@"tabBarText" baseFont:[UIFont systemFontOfSize:10]];
    if (!unselectedAttributes[NSForegroundColorAttributeName] && labelColor) {
      unselectedAttributes[NSForegroundColorAttributeName] = labelColor;
    }
    
    [viewController.tabBarItem setTitleTextAttributes:unselectedAttributes forState:UIControlStateNormal];
    
    NSMutableDictionary *selectedAttributes = [RCTHelpers textAttributesFromDictionary:tabsStyle withPrefix:@"tabBarSelectedText" baseFont:[UIFont systemFontOfSize:10]];
    if (!selectedAttributes[NSForegroundColorAttributeName] && selectedLabelColor) {
      selectedAttributes[NSForegroundColorAttributeName] = selectedLabelColor;
    }
    
    [viewController.tabBarItem setTitleTextAttributes:selectedAttributes forState:UIControlStateSelected];
    // create badge
    NSObject *badge = tabItemLayout[@"props"][@"badge"];
    /* annotation by：zyxiao @2019.3.15
     if (badge == nil || [badge isEqual:[NSNull null]])
     {
     viewController.tabBarItem.badgeValue = nil;
     }
     else
     {
     viewController.tabBarItem.badgeValue = [NSString stringWithFormat:@"%@", badge];
     }
     */
    [self refreshBadgeWithValue:badge color:nil atIndex:[children indexOfObject:tabItemLayout]];
    
    [viewControllers addObject:viewController];
  }
  
  // replace the tabs
  self.viewControllers = viewControllers;

  [self repalceTabbarBg];
  
  NSNumber *initialTab = tabsStyle[@"initialTabIndex"];
  if (initialTab)
  {
    NSInteger initialTabIndex = initialTab.integerValue;
    [self setSelectedIndex:initialTabIndex];
  }
  
  [self setRotation:props];
  
  return self;
}

- (void)repalceTabbarBg {
  BOOL isIpad = [ self getIsIpad];
  if (!isIpad) {
    [[UITabBarItem appearance] setTitlePositionAdjustment:UIOffsetMake(0, -4)];
  }
  
  // CGRect rect = CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, 0.5);
  // UIGraphicsBeginImageContext(rect.size);
  // CGContextRef context = UIGraphicsGetCurrentContext();
  // CGColorRef color = [[UIColor colorWithRed:(14.0 * 16/255) green:(14.0 * 16/255) blue:(14.0 * 16/255) alpha:1.0f] CGColor];;
  // CGContextSetFillColor(context, CGColorGetComponents(color));
  // CGContextFillRect(context, rect);
  // UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
  // UIGraphicsEndImageContext();
  
  // [[UITabBar appearance] setBackgroundImage:[UIImage new]];
  // [[UITabBar appearance] setShadowImage:img];
}


- (BOOL)getIsIpad {
  NSString *deviceType = [UIDevice currentDevice].model;
  if([deviceType isEqualToString:@"iPad"]) {
    return YES;
  } else {
    return NO;
  }
}

- (void)performAction:(NSString*)performAction actionParams:(NSDictionary*)actionParams bridge:(RCTBridge *)bridge completion:(void (^)(void))completion
{
  if ([performAction isEqualToString:@"setBadge"])
  {
    UIViewController *viewController = nil;
    NSNumber *tabIndex = actionParams[@"tabIndex"];
    if (tabIndex)
    {
      int i = (int)[tabIndex integerValue];
      
      if ([self.viewControllers count] > i)
      {
        viewController = [self.viewControllers objectAtIndex:i];
      }
    }
    NSString *contentId = actionParams[@"contentId"];
    NSString *contentType = actionParams[@"contentType"];
    if (contentId && contentType)
    {
      viewController = [[RCCManager sharedInstance] getControllerWithId:contentId componentType:contentType];
    }
    
    if (viewController)
    {
      NSObject *badge = actionParams[@"badge"];
      NSString *badgeColor = actionParams[@"badgeColor"];
      UIColor *color = badgeColor != (id)[NSNull null] ? [RCTConvert UIColor:badgeColor] : nil;
      [self refreshBadgeWithValue:badge color:color atIndex:[tabIndex unsignedIntegerValue]];
      /* annotation by：zyxiao @2019.3.15
       if (badge == nil || [badge isEqual:[NSNull null]])
       {
       viewController.tabBarItem.badgeValue = nil;
       }
       else
       {
       NSString *badgeColor = actionParams[@"badgeColor"];
       UIColor *color = badgeColor != (id)[NSNull null] ? [RCTConvert UIColor:badgeColor] : nil;
       
       if ([viewController.tabBarItem respondsToSelector:@selector(badgeColor)]) {
       viewController.tabBarItem.badgeColor = color;
       }
       viewController.tabBarItem.badgeValue = [NSString stringWithFormat:@"%@", badge];
       }
       */
    }
  }
  
  if ([performAction isEqualToString:@"switchTo"])
  {
    UIViewController *viewController = nil;
    NSNumber *tabIndex = actionParams[@"tabIndex"];
    if (tabIndex)
    {
      int i = (int)[tabIndex integerValue];
      
      if ([self.viewControllers count] > i)
      {
        viewController = [self.viewControllers objectAtIndex:i];
      }
    }
    NSString *contentId = actionParams[@"contentId"];
    NSString *contentType = actionParams[@"contentType"];
    if (contentId && contentType)
    {
      viewController = [[RCCManager sharedInstance] getControllerWithId:contentId componentType:contentType];
    }
    
    if (viewController)
    {
      [self setSelectedViewController:viewController];
    }
  }
  
  if ([performAction isEqualToString:@"setTabButton"])
  {
    UIViewController *viewController = nil;
    NSNumber *tabIndex = actionParams[@"tabIndex"];
    if (tabIndex)
    {
      int i = (int)[tabIndex integerValue];
      
      if ([self.viewControllers count] > i)
      {
        viewController = [self.viewControllers objectAtIndex:i];
      }
    }
    NSString *contentId = actionParams[@"contentId"];
    NSString *contentType = actionParams[@"contentType"];
    if (contentId && contentType)
    {
      viewController = [[RCCManager sharedInstance] getControllerWithId:contentId componentType:contentType];
    }
    
    if (viewController)
    {
      UIImage *iconImage = nil;
      id icon = actionParams[@"icon"];
      if (icon && icon != (id)[NSNull null])
      {
        iconImage = [RCTConvert UIImage:icon];
        /* 2019.12.11@zyxiao 修复测试bug“【书链APP-ios】tap底部图片未全部填充”，隐藏这一句就行；
        iconImage = [[self image:iconImage withColor:self.tabBar.tintColor] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
         */
        viewController.tabBarItem.image = iconImage;
      }
      
      UIImage *iconImageSelected = nil;
      id selectedIcon = actionParams[@"selectedIcon"];
      if (selectedIcon && selectedIcon != (id)[NSNull null])
      {
        iconImageSelected = [RCTConvert UIImage:selectedIcon];
        viewController.tabBarItem.selectedImage = iconImageSelected;
      }
      
      id label = actionParams[@"label"];
      if (label && label != (id)[NSNull null])
      {
        viewController.tabBarItem.title = label;
      }
    }
  }
  
  if ([performAction isEqualToString:@"setTabBarHidden"])
  {
    BOOL hidden = [actionParams[@"hidden"] boolValue];
    self.tabBarHidden = hidden;
    
    CGRect nextFrame = self.tabBar.frame;
    nextFrame.origin.y = UIScreen.mainScreen.bounds.size.height - (hidden ? -10 : self.tabBar.frame.size.height);
    if(hidden){
      nextFrame.size.height = 0;
    }
    
    [UIView animateWithDuration: ([actionParams[@"animated"] boolValue] ? 0.45 : 0)
                          delay: 0
         usingSpringWithDamping: 0.75
          initialSpringVelocity: 0
                        options: (hidden ? UIViewAnimationOptionCurveEaseIn : UIViewAnimationOptionCurveEaseOut)
                     animations:^()
     {
         [self.tabBar setFrame:nextFrame];
     }
                     completion:^(BOOL finished)
     {
       if (completion != nil)
       {
         completion();
       }
     }];
    return;
  }
  else if (completion != nil)
  {
    completion();
  }
}

+(void)sendScreenTabChangedEvent:(UIViewController*)viewController body:(NSDictionary*)body{
  [RCCTabBarController sendTabEvent:@"bottomTabSelected" controller:viewController body:body];
}

+(void)sendScreenTabPressedEvent:(UIViewController*)viewController body:(NSDictionary*)body{
  [RCCTabBarController sendTabEvent:@"bottomTabReselected" controller:viewController body:body];
}

+(void)sendTabEvent:(NSString *)event controller:(UIViewController*)viewController body:(NSDictionary*)body{
  if ([viewController.view isKindOfClass:[RCTRootView class]]){
    RCTRootView *rootView = (RCTRootView *)viewController.view;
    
    if (rootView.appProperties && rootView.appProperties[@"navigatorEventID"]) {
      NSString *navigatorID = rootView.appProperties[@"navigatorID"];
      NSString *screenInstanceID = rootView.appProperties[@"screenInstanceID"];
      
      
      NSMutableDictionary *screenDict = [NSMutableDictionary dictionaryWithDictionary:@
                                         {
                                           @"id": event,
                                           @"navigatorID": navigatorID,
                                           @"screenInstanceID": screenInstanceID
                                         }];
      
      
      if (body) {
        [screenDict addEntriesFromDictionary:body];
      }
      
      [[[RCCManager sharedInstance] getBridge].eventDispatcher sendAppEventWithName:rootView.appProperties[@"navigatorEventID"] body:screenDict];
    }
  }
  
  if ([viewController isKindOfClass:[UINavigationController class]]) {
    UINavigationController *navigationController = (UINavigationController*)viewController;
    UIViewController *topViewController = [navigationController topViewController];
    [RCCTabBarController sendTabEvent:event controller:topViewController body:body];
  }
}

// 自定义小圆点（by：zyxiao @2019.3.15）
- (void)initializeDotArrWithTotalCount:(NSUInteger)totalCount {
  if (totalCount) {
    self.dotArr = [NSMutableArray arrayWithCapacity:totalCount];
    for (int i = 0; i < (int)totalCount; i ++) {
      [self.dotArr addObject:[NSNull null]];
    }
  }
}
// 自定义小圆点（by：zyxiao @2019.3.15）
- (void)refreshBadgeWithValue:(id)value color:(UIColor *)color atIndex:(NSUInteger)index {
  UITabBarItem *tabBarItem = self.tabBar.items[index];
  if (value == nil || [value isEqual:[NSNull null]]) {
    tabBarItem.badgeValue = nil;
    UIView *dot = self.dotArr[index];
    if (![dot isEqual:[NSNull null]]) {
      [dot removeFromSuperview];
      [self.dotArr replaceObjectAtIndex:index withObject:[NSNull null]];
    }
  } else if ([value isEqualToString:@" "]) {
    tabBarItem.badgeValue = nil;
    UIView *dot = self.dotArr[index];
    if ([dot isEqual:[NSNull null]]) {
      UIView *dot = [self dotWithColor:color atIndex:index];
      [self.tabBar addSubview:dot];
      [self.dotArr replaceObjectAtIndex:index withObject:dot];
    }
  } else {
    tabBarItem.badgeValue = [NSString stringWithFormat:@"%@", value];
    UIView *dot = self.dotArr[index];
    if (![dot isEqual:[NSNull null]]) {
      [dot removeFromSuperview];
      [self.dotArr replaceObjectAtIndex:index withObject:[NSNull null]];
    }
  }
}
// 自定义小圆点（by：zyxiao @2019.3.15）
- (UIView *)dotWithColor:(UIColor *)dotColor atIndex:(NSUInteger)index {
  CGRect tabBounds = self.tabBar.bounds;
  NSUInteger tabCount = self.dotArr.count;
  UIView *dot = [[UIView alloc] initWithFrame:CGRectMake((tabBounds.size.width*(2*index+1))/(tabCount*2)+7.5, 3.5, 10, 10)];
  dot.backgroundColor = dotColor ? dotColor : [UIColor redColor];
  dot.layer.cornerRadius = 5;
  dot.layer.masksToBounds = YES;
  return dot;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator {
  // 这里必须要调用super，不调用super其它地方将获取不到app显示尺寸变化的事件；
  [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator]; 
  // iPad在前后台切换的时候也会触发该方法，iPhone则不会，用下面代码控制；
  if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
    return;
  }
  if (!self.emitter) {
    self.emitter = [[RCCEventEmitter alloc] init];
  }
  [self.emitter sendEventWithName:@"screenSizeDidChange" info:@{@"width": @(size.width), @"height": @(size.height)}];
}


@end
