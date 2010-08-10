//  Created by Sean Heber on 6/24/10.
#import "UIControl.h"
#import "UIEvent.h"
#import "UITouch.h"
#import "UIApplication.h"

@interface _UIControlAction : NSObject {
	id target;
	SEL action;
	UIControlEvents controlEvents;
}
@property (nonatomic, assign) id target;
@property (nonatomic, assign) SEL action;
@property (nonatomic, assign) UIControlEvents controlEvents;
@end

@implementation _UIControlAction
@synthesize target, action, controlEvents;
@end

@implementation UIControl
@synthesize tracking=_tracking, touchInside=_touchInside, selected=_selected, enabled=_enabled, highlighted=_highlighted;
@synthesize contentHorizontalAlignment=_contentHorizontalAlignment, contentVerticalAlignment=_contentVerticalAlignment;

- (id)initWithFrame:(CGRect)frame
{
	if ((self=[super initWithFrame:frame])) {
		_registeredActions = [NSMutableArray new];
		self.enabled = YES;
		self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
		self.contentVerticalAlignment = UIControlContentVerticalAlignmentTop;
	}
	return self;
}

- (void)dealloc
{
	[_registeredActions release];
	[super dealloc];
}

- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents
{
	_UIControlAction *controlAction = [_UIControlAction new];
	controlAction.target = target;
	controlAction.action = action;
	controlAction.controlEvents = controlEvents;
	[_registeredActions addObject:controlAction];
	[controlAction release];
}

- (void)removeTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents
{
	NSMutableArray *discard = [NSMutableArray new];
	
	for (_UIControlAction *controlAction in _registeredActions) {
		if (controlAction.target == target && (action == NULL || controlAction.controlEvents == controlEvents)) {
			[discard addObject:controlAction];
		}
	}
	
	[_registeredActions removeObjectsInArray:discard];
	[discard release];
}

- (NSArray *)actionsForTarget:(id)target forControlEvent:(UIControlEvents)controlEvent
{
	NSMutableArray *actions = [NSMutableArray new];
	
	for (_UIControlAction *controlAction in _registeredActions) {
		if ((target == nil || controlAction.target == target) && (controlAction.controlEvents & controlEvent) ) {
			[actions addObject:NSStringFromSelector(controlAction.action)];
		}
	}
	
	if ([actions count] == 0) {
		[actions release];
		return nil;
	} else {
		return [actions autorelease];
	}
}

- (NSSet *)allTargets
{
	return [NSSet setWithArray:[_registeredActions valueForKey:@"target"]];
}

- (UIControlEvents)allControlEvents
{
	UIControlEvents allEvents = 0;
	
	for (_UIControlAction *controlAction in _registeredActions) {
		allEvents |= controlAction.controlEvents;
	}
	
	return allEvents;
}

- (void)_sendActionsForControlEvents:(UIControlEvents)controlEvents withEvent:(UIEvent *)event
{
	for (_UIControlAction *controlAction in _registeredActions) {
		if (controlAction.controlEvents & controlEvents) {
			[self sendAction:controlAction.action to:controlAction.target forEvent:event];
		}
	}
}

- (void)sendActionsForControlEvents:(UIControlEvents)controlEvents
{
	[self _sendActionsForControlEvents:controlEvents withEvent:nil];
}

- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event
{
	[[UIApplication sharedApplication] sendAction:action to:target from:self forEvent:event];
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
	return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
	return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
}

- (void)cancelTrackingWithEvent:(UIEvent *)event
{
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	_touchInside = YES;
	_tracking = [self beginTrackingWithTouch:touch withEvent:event];

	if (_tracking) {
		UIControlEvents currentEvents = UIControlEventTouchDown;

		if (touch.tapCount > 1) {
			currentEvents |= UIControlEventTouchDownRepeat;
		}

		[self _sendActionsForControlEvents:currentEvents withEvent:event];
	}

	self.highlighted = YES;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	const BOOL wasTouchInside = _touchInside;
	_touchInside = [self pointInside:[touch locationInView:self] withEvent:event];

	if (_tracking) {
		_tracking = [self continueTrackingWithTouch:touch withEvent:event];
		if (_tracking) {
			UIControlEvents currentEvents = ((_touchInside)? UIControlEventTouchDragInside : UIControlEventTouchDragOutside);

			if (!wasTouchInside && _touchInside) {
				currentEvents |= UIControlEventTouchDragEnter;
			} else if (wasTouchInside && !_touchInside) {
				currentEvents |= UIControlEventTouchDragExit;
			}

			[self _sendActionsForControlEvents:currentEvents withEvent:event];
		}
	}
	
	self.highlighted = _touchInside;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	_touchInside = [self pointInside:[touch locationInView:self] withEvent:event];

	if (_tracking) {
		[self endTrackingWithTouch:touch withEvent:event];
		[self _sendActionsForControlEvents:((_touchInside)? UIControlEventTouchUpInside : UIControlEventTouchUpOutside) withEvent:event];
	}

	_tracking = NO;
	_touchInside = NO;
	self.highlighted = NO;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (_tracking) {
		[self cancelTrackingWithEvent:event];
		[self _sendActionsForControlEvents:UIControlEventTouchCancel withEvent:event];
	}

	_touchInside = NO;
	_tracking = NO;
}

- (void)_stateDidChange
{
	[self setNeedsDisplay];
}

- (void)setEnabled:(BOOL)newEnabled
{
	if (newEnabled != _enabled) {
		_enabled = newEnabled;
		[self _stateDidChange];
		self.userInteractionEnabled = _enabled;
	}
}

- (void)setHighlighted:(BOOL)newHighlighted
{
	if (newHighlighted != _highlighted) {
		_highlighted = newHighlighted;
		[self _stateDidChange];
	}
}

- (void)setSelected:(BOOL)newSelected
{
	if (newSelected != _selected) {
		_selected = newSelected;
		[self _stateDidChange];
	}
}

- (UIControlState)state
{
	UIControlState state = UIControlStateNormal;
	
	if (_highlighted)	state |= UIControlStateHighlighted;
	if (!_enabled)		state |= UIControlStateDisabled;
	if (_selected)		state |= UIControlStateSelected;

	return state;
}

@end
