#import "TPController.h"
#import "TPProbe.h"
#import "TPCrash.h"

@implementation TPController {
    UITextView *_text;
    UIButton *_start;
    UIButton *_copy;
    UILabel *_hint;
    TPProbe *_probe;
    NSMutableString *_report;
}

static UIButton *MakeButton(NSString *title, UIColor *top)
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [b setTitleColor:[UIColor colorWithWhite:0.8 alpha:1] forState:UIControlStateDisabled];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    b.backgroundColor = top;
    b.layer.cornerRadius = 8;
    b.layer.borderWidth = 1;
    b.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
    return b;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Sonda Teams";
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.13 alpha:1];
    CGRect b = self.view.bounds;

    _hint = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, b.size.width - 24, 52)];
    _hint.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _hint.numberOfLines = 3;
    _hint.backgroundColor = [UIColor clearColor];
    _hint.textColor = [UIColor colorWithWhite:0.8 alpha:1];
    _hint.font = [UIFont systemFontOfSize:13];
    _hint.text = @"Test sprawdza, czy ten telefon połączy się przez HTTPS z serwerami Microsoftu (Teams). Nic nie logujesz i nic nie wysyłasz.";
    [self.view addSubview:_hint];

    _start = MakeButton(@"Uruchom test", [UIColor colorWithRed:0.25 green:0.30 blue:0.80 alpha:1]);
    _start.frame = CGRectMake(12, 64, (b.size.width - 36) / 2, 44);
    _start.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    [_start addTarget:self action:@selector(startTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_start];

    _copy = MakeButton(@"Kopiuj raport", [UIColor colorWithRed:0.20 green:0.45 blue:0.30 alpha:1]);
    _copy.frame = CGRectMake(24 + (b.size.width - 36) / 2, 64, (b.size.width - 36) / 2, 44);
    _copy.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
    [_copy addTarget:self action:@selector(copyTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_copy];

    _text = [[UITextView alloc] initWithFrame:CGRectMake(8, 118, b.size.width - 16, b.size.height - 126)];
    _text.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _text.editable = NO;
    _text.font = [UIFont fontWithName:@"Courier" size:11];
    _text.backgroundColor = [UIColor colorWithRed:0.03 green:0.04 blue:0.07 alpha:1];
    _text.textColor = [UIColor colorWithRed:0.85 green:0.95 blue:0.85 alpha:1];
    _text.text = @"Naciśnij „Uruchom test”. Test trwa do ok. 2 minut (każde zapytanie ma 20 s limitu). Potem naciśnij „Kopiuj raport” i wklej całość do rozmowy.";
    [self.view addSubview:_text];
    _report = [NSMutableString string];
}

- (void)startTapped
{
    if (_probe.running) return;
    _probe = [[TPProbe alloc] init];
    [_report setString:@""];
    _text.text = @"";
    _start.enabled = NO;
    _start.alpha = 0.6;
    __weak TPController *me = self;
    [_probe runWithLog:^(NSString *t) {
        TPController *s = me;
        if (!s) return;
        [s->_report appendString:t];
        s->_text.text = s->_report;
        NSUInteger len = [s->_report length];
        if (len > 2) [s->_text scrollRangeToVisible:NSMakeRange(len - 1, 1)];
    } done:^{
        TPController *s = me;
        if (!s) return;
        s->_start.enabled = YES;
        s->_start.alpha = 1;
        [s->_report appendString:@"\n(koniec raportu)\n"];
        s->_text.text = s->_report;
    }];
}

- (void)copyTapped
{
    if (![_report length]) return;
    [UIPasteboard generalPasteboard].string = _report;
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Skopiowano"
                                                message:@"Raport jest w schowku. Wklej go do rozmowy."
                                               delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [a show];
}

@end
