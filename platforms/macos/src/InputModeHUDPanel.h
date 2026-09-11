#pragma once

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 中 or 英 -- the state being switched to, as one character.
FOUNDATION_EXPORT NSString *MetasequoiaInputModeHUDText(BOOL englishInputMode);

/// Sits under the caret, close enough to be seen without looking away from what is being typed, and
/// clamped inside the screen. A client that reports no usable caret -- a terminal mid-redraw, a web
/// view that answers with zeroes -- gets the lower middle of the screen instead of a badge pinned to
/// the corner.
FOUNDATION_EXPORT NSRect MetasequoiaInputModeHUDFrame(NSRect caretRect, NSSize panelSize, NSRect visibleFrame);

FOUNDATION_EXPORT BOOL MetasequoiaIsUsableCaretRect(NSRect caretRect);

/// The badge that says which mode a switch landed in. It shows itself, waits, and fades out; it
/// never takes focus and never takes a click.
@interface MetasequoiaInputModeHUDPanel : NSPanel
+ (instancetype)sharedPanel;
- (void)showEnglishInputMode:(BOOL)englishInputMode nearCaretRect:(NSRect)caretRect;
/// Visible for tests: the text currently on the badge, or nil when it is hidden.
@property(nonatomic, copy, readonly, nullable) NSString *displayedText;
@end

NS_ASSUME_NONNULL_END
