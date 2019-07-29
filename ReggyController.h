/* ReggyController */

#import <Cocoa/Cocoa.h>

@interface ReggyController : NSObject
{
	IBOutlet NSWindow * mainWindow;
	IBOutlet NSButton * matchCaseButton;
	IBOutlet NSButton * matchMultiLineButton;
	IBOutlet NSTextView * regexPatternField;
	IBOutlet NSTextView * testingStringField;
	IBOutlet NSTextField * statusText;
}

@property (assign, nonatomic) BOOL matchCase;
@property (assign, nonatomic) BOOL matchMultiLine;
@property (assign, nonatomic) BOOL hideErrorImage;

- (IBAction) match:(id)sender;
- (IBAction) pasteAsRegEx:(id)sender;
- (IBAction) pasteAsTestString:(id)sender;
- (IBAction) openRegularExpressionHelpInBrowser:(id)sender;

@end

@interface ReggyController ()

@property (copy, nonatomic) NSString *regularExpression;
@property (copy, nonatomic) NSString *testString;

@end
