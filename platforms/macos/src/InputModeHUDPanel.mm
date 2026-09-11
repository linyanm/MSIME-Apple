#import "InputModeHUDPanel.h"

#import <cmath>

namespace
{
constexpr CGFloat kPanelSide = 64.0;
constexpr CGFloat kCornerRadius = 14.0;
constexpr CGFloat kScreenMargin = 8.0;
constexpr CGFloat kCaretGap = 10.0;
// Long enough to be read at a glance, short enough that it is gone before the next word is typed.
constexpr NSTimeInterval kVisibleDuration = 0.6;
constexpr NSTimeInterval kFadeDuration = 0.18;

CGFloat Clamp(CGFloat value, CGFloat minimum, CGFloat maximum)
{
    if (maximum < minimum)
    {
        return minimum;
    }
    return value < minimum ? minimum : (value > maximum ? maximum : value);
}
} // namespace

NSString *MetasequoiaInputModeHUDText(BOOL englishInputMode)
{
    return englishInputMode ? @"英" : @"中";
}

BOOL MetasequoiaIsUsableCaretRect(NSRect caretRect)
{
    return std::isfinite(NSMinX(caretRect)) && std::isfinite(NSMinY(caretRect)) && std::isfinite(NSMaxX(caretRect)) &&
           std::isfinite(NSMaxY(caretRect)) && NSHeight(caretRect) > 0.0;
}

NSRect MetasequoiaInputModeHUDFrame(NSRect caretRect, NSSize panelSize, NSRect visibleFrame)
{
    const CGFloat minimumX = NSMinX(visibleFrame) + kScreenMargin;
    const CGFloat maximumX = NSMaxX(visibleFrame) - kScreenMargin - panelSize.width;
    const CGFloat minimumY = NSMinY(visibleFrame) + kScreenMargin;
    const CGFloat maximumY = NSMaxY(visibleFrame) - kScreenMargin - panelSize.height;

    if (!MetasequoiaIsUsableCaretRect(caretRect))
    {
        const CGFloat centredX = NSMidX(visibleFrame) - panelSize.width / 2.0;
        const CGFloat lowerThirdY = NSMinY(visibleFrame) + NSHeight(visibleFrame) / 4.0;
        return NSMakeRect(Clamp(centredX, minimumX, maximumX), Clamp(lowerThirdY, minimumY, maximumY), panelSize.width,
                          panelSize.height);
    }

    // Centred on the caret and below it, so it does not cover the line being typed. It goes above
    // only when there is no room underneath.
    const CGFloat x = Clamp(NSMidX(caretRect) - panelSize.width / 2.0, minimumX, maximumX);
    const CGFloat belowY = NSMinY(caretRect) - kCaretGap - panelSize.height;
    const CGFloat preferredY = belowY >= minimumY ? belowY : NSMaxY(caretRect) + kCaretGap;
    return NSMakeRect(x, Clamp(preferredY, minimumY, maximumY), panelSize.width, panelSize.height);
}

@implementation MetasequoiaInputModeHUDPanel
{
    NSTextField *_label;
    NSTimer *_dismissTimer;
}

+ (instancetype)sharedPanel
{
    static MetasequoiaInputModeHUDPanel *panel = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      panel = [[MetasequoiaInputModeHUDPanel alloc] init];
    });
    return panel;
}

- (instancetype)init
{
    self = [super initWithContentRect:NSMakeRect(0.0, 0.0, kPanelSide, kPanelSide)
                            styleMask:(NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel)
                              backing:NSBackingStoreBuffered
                                defer:YES];
    if (self == nil)
    {
        return nil;
    }

    self.floatingPanel = YES;
    self.level = NSPopUpMenuWindowLevel;
    self.becomesKeyOnlyIfNeeded = YES;
    self.hidesOnDeactivate = NO;
    self.opaque = NO;
    self.backgroundColor = [NSColor clearColor];
    self.hasShadow = YES;
    self.ignoresMouseEvents = YES;
    self.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                              NSWindowCollectionBehaviorFullScreenAuxiliary | NSWindowCollectionBehaviorTransient |
                              NSWindowCollectionBehaviorIgnoresCycle;
    self.animationBehavior = NSWindowAnimationBehaviorNone;

    NSVisualEffectView *background =
        [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, kPanelSide, kPanelSide)];
    background.material = NSVisualEffectMaterialHUDWindow;
    background.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    background.state = NSVisualEffectStateActive;
    background.wantsLayer = YES;
    background.layer.cornerRadius = kCornerRadius;
    background.layer.masksToBounds = YES;
    background.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    _label = [NSTextField labelWithString:@""];
    _label.alignment = NSTextAlignmentCenter;
    _label.font = [NSFont systemFontOfSize:32.0 weight:NSFontWeightMedium];
    _label.textColor = [NSColor labelColor];
    _label.translatesAutoresizingMaskIntoConstraints = NO;
    [background addSubview:_label];
    [NSLayoutConstraint activateConstraints:@[
        [_label.centerXAnchor constraintEqualToAnchor:background.centerXAnchor],
        [_label.centerYAnchor constraintEqualToAnchor:background.centerYAnchor],
    ]];

    self.contentView = background;
    return self;
}

- (NSString *)displayedText
{
    return self.isVisible ? _label.stringValue : nil;
}

- (void)showEnglishInputMode:(BOOL)englishInputMode nearCaretRect:(NSRect)caretRect
{
    _label.stringValue = MetasequoiaInputModeHUDText(englishInputMode);
    // The badge announces a state the user just chose, so it is spoken rather than left to be found.
    NSAccessibilityPostNotificationWithUserInfo(
        self, NSAccessibilityAnnouncementRequestedNotification,
        @{NSAccessibilityAnnouncementKey : englishInputMode ? @"英文输入" : @"中文输入"});

    NSScreen *screen = [NSScreen screens].firstObject;
    for (NSScreen *candidate in [NSScreen screens])
    {
        if (NSPointInRect(NSMakePoint(NSMidX(caretRect), NSMidY(caretRect)), candidate.frame))
        {
            screen = candidate;
            break;
        }
    }
    const NSRect visibleFrame = screen != nil ? screen.visibleFrame : NSMakeRect(0, 0, 1440, 900);
    [self setFrame:MetasequoiaInputModeHUDFrame(caretRect, NSMakeSize(kPanelSide, kPanelSide), visibleFrame)
           display:YES];

    [_dismissTimer invalidate];
    self.alphaValue = 1.0;
    [self orderFrontRegardless];

    __weak MetasequoiaInputModeHUDPanel *weakSelf = self;
    _dismissTimer = [NSTimer scheduledTimerWithTimeInterval:kVisibleDuration
                                                    repeats:NO
                                                      block:^(NSTimer *timer) {
                                                        (void)timer;
                                                        [weakSelf fadeOut];
                                                      }];
}

- (void)fadeOut
{
    [NSAnimationContext
        runAnimationGroup:^(NSAnimationContext *context) {
          context.duration = kFadeDuration;
          self.animator.alphaValue = 0.0;
        }
        completionHandler:^{
          // A switch during the fade has already raised the alpha again; hiding here would undo it.
          if (self.alphaValue <= 0.01)
          {
              [self orderOut:nil];
          }
        }];
}

@end
