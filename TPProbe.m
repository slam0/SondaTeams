#import "TPProbe.h"
#import "TPCrash.h"
#import <Security/Security.h>
#import <UIKit/UIKit.h>

/*
 * Uwaga (iOS 6): klasy sieciowe (NSURL, NSMutableURLRequest, NSURLConnection, NSURLCredential) wyszukujemy po nazwie
 * w czasie działania. Zastępcze pliki SDK, z których budujemy aplikację, przypisują je do CFNetwork, a na iOS 6 ich tam nie ma
 * (dyld: "Symbol not found"). Dlatego nie ma tu twardych odwołań do tych klas, a stałe są zwykłymi napisami.
 */

#define TP_TIMEOUT 20.0

/* ---- jedno zapytanie ---- */

@interface TPRequest : NSObject
@property (copy) NSString *title, *method, *url, *body, *expect;
@property (copy) NSString *response;           /* wynik przetworzony na tekst */
@property (copy) NSString *errorText;
@property (copy) NSString *chain;              /* łańcuch certyfikatów */
@property NSInteger status;                    /* kod HTTP, 0 = brak odpowiedzi */
@property NSInteger errCode;                   /* kod błędu NSURLError, 0 = brak */
@property int trustState;                      /* 0 brak wyzwania, 1 zaufany, 2 niezaufany */
@property int trustResult;                     /* surowy wynik SecTrustEvaluate */
@property NSUInteger bytes;
@property double ms;
@property BOOL gotChallenge;
@end
@implementation TPRequest
@end

/* ---- delegat jednego połączenia ---- */

@interface TPConn : NSObject
@property (strong) TPRequest *req;
@property (strong) NSMutableData *data;
@property (copy) void (^finish)(void);
@property (strong) id connection;
@property double t0;
@property BOOL done;
- (void)start;
@end

static NSString *CertSummary(SecCertificateRef c)
{
    CFStringRef s = SecCertificateCopySubjectSummary(c);
    if (!s) return @"(bez nazwy)";
    return (NSString *)CFBridgingRelease(s);
}

static NSString *TrustResultName(int r)
{
    switch (r) {
        case 0: return @"Invalid";
        case 1: return @"Proceed";
        case 2: return @"Confirm";
        case 3: return @"Deny";
        case 4: return @"Unspecified (zaufany)";
        case 5: return @"RecoverableTrustFailure (niezaufany)";
        case 6: return @"FatalTrustFailure";
        case 7: return @"OtherError";
    }
    return [NSString stringWithFormat:@"%d", r];
}

@implementation TPConn

- (void)start
{
    Class urlClass = NSClassFromString(@"NSURL");
    Class requestClass = NSClassFromString(@"NSMutableURLRequest");
    Class connClass = NSClassFromString(@"NSURLConnection");
    if (!urlClass || !requestClass || !connClass) {
        _req.errorText = @"Brak klas sieciowych w systemie.";
        [self complete];
        return;
    }
    id u = [urlClass URLWithString:_req.url];
    id r = [requestClass requestWithURL:u cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:TP_TIMEOUT];
    [r setHTTPMethod:_req.method];
    [r setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    if ([_req.body length]) {
        [r setHTTPBody:[_req.body dataUsingEncoding:NSUTF8StringEncoding]];
        [r setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    }
    _data = [NSMutableData data];
    _t0 = [[NSDate date] timeIntervalSince1970];
    TPCrumb([@"zapytanie: " stringByAppendingString:_req.url]);
    _connection = [[connClass alloc] initWithRequest:r delegate:self startImmediately:YES];
    if (!_connection) {
        _req.errorText = @"Nie udało się utworzyć połączenia.";
        [self complete];
    }
}

- (void)complete
{
    if (_done) return;
    _done = YES;
    _req.ms = ([[NSDate date] timeIntervalSince1970] - _t0) * 1000.0;
    _req.bytes = [_data length];
    if ([_data length]) {
        NSString *t = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
        if (!t) t = @"(dane binarne)";
        t = [t stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        if ([t length] > 160) t = [[t substringToIndex:160] stringByAppendingString:@"…"];
        _req.response = t;
    }
    _connection = nil;
    if (_finish) _finish();
}

/* Wyzwanie certyfikatu serwera: zapisujemy, czy iOS go uznaje, i wypisujemy łańcuch. Połączenie kontynuujemy zawsze (tylko do
   testu - wysyłamy wyłącznie puste zapytania bez żadnych danych), żeby było widać, czy sam protokół TLS działa. */
- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSString *method = [[challenge protectionSpace] authenticationMethod];
    if (![method isEqualToString:@"NSURLAuthenticationMethodServerTrust"]) {
        [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
        return;
    }
    _req.gotChallenge = YES;
    SecTrustRef trust = [[challenge protectionSpace] serverTrust];
    if (!trust) {
        [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
        return;
    }
    SecTrustResultType result = 0;
    OSStatus st = SecTrustEvaluate(trust, &result);
    _req.trustResult = (int)result;
    BOOL ok = (st == 0) && (result == 4 || result == 1);   /* Unspecified / Proceed */
    _req.trustState = ok ? 1 : 2;
    CFIndex n = SecTrustGetCertificateCount(trust);
    NSMutableString *chain = [NSMutableString string];
    for (CFIndex i = 0; i < n; i++) {
        SecCertificateRef c = SecTrustGetCertificateAtIndex(trust, i);
        [chain appendFormat:@"%@%@", i ? @" → " : @"", CertSummary(c)];
    }
    _req.chain = chain;
    Class credClass = NSClassFromString(@"NSURLCredential");
    id cred = credClass ? [credClass credentialForTrust:trust] : nil;
    if (cred) [[challenge sender] useCredential:cred forAuthenticationChallenge:challenge];
    else [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if ([response respondsToSelector:@selector(statusCode)]) _req.status = [(NSHTTPURLResponse *)response statusCode];
    else _req.status = 200;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)d
{
    if ([_data length] < 65536) [_data appendData:d];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self complete];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    _req.errCode = [error code];
    _req.errorText = [NSString stringWithFormat:@"%@ %ld: %@", [error domain], (long)[error code], [error localizedDescription]];
    [self complete];
}

@end

/* ---- cały test ---- */

@implementation TPProbe {
    NSMutableArray *_queue;
    NSMutableArray *_done;
    TPLogBlock _log;
    TPDoneBlock _final;
    TPConn *_current;
    BOOL _running;
}

- (BOOL)running { return _running; }

static TPRequest *Make(NSString *title, NSString *method, NSString *url, NSString *body, NSString *expect)
{
    TPRequest *r = [[TPRequest alloc] init];
    r.title = title; r.method = method; r.url = url; r.body = body; r.expect = expect;
    return r;
}

- (void)runWithLog:(TPLogBlock)log done:(TPDoneBlock)done
{
    if (_running) return;
    _running = YES;
    _log = [log copy];
    _final = [done copy];
    _done = [NSMutableArray array];
    _queue = [NSMutableArray array];
    [_queue addObject:Make(@"1. Kontrola: zwykła strona z kursami (to samo robi Currency)", @"GET",
                           @"https://open.er-api.com/v6/latest/USD", nil, @"HTTP 200")];
    [_queue addObject:Make(@"2. Kontrola: GitHub (certyfikat DigiCert)", @"GET",
                           @"https://github.com/", nil, @"HTTP 200")];
    [_queue addObject:Make(@"3. Microsoft: konfiguracja logowania", @"GET",
                           @"https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration", nil, @"HTTP 200")];
    [_queue addObject:Make(@"4. Microsoft: logowanie metodą kodu (POST)", @"POST",
                           @"https://login.microsoftonline.com/common/oauth2/v2.0/devicecode",
                           @"client_id=00000000-0000-0000-0000-000000000000&scope=Chat.ReadWrite",
                           @"HTTP 400 z komunikatem AADSTS (to dobry znak: serwer odpowiedział)")];
    [_queue addObject:Make(@"5. Microsoft Graph (bez tokenu)", @"GET",
                           @"https://graph.microsoft.com/v1.0/me", nil, @"HTTP 401 (to dobry znak: serwer odpowiedział)")];
    [_queue addObject:Make(@"6. Skype: stary serwer logowania (dla porównania)", @"GET",
                           @"https://api.skype.com/", nil, @"dowolna odpowiedź albo błąd")];

    UIDevice *d = [UIDevice currentDevice];
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    [f setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [self emit:[NSString stringWithFormat:@"SONDA TEAMS 0.1.0\nUrządzenie: %@, iOS %@\nData telefonu: %@\n\n",
                [d model], [d systemVersion], [f stringFromDate:[NSDate date]]]];
    [self next];
}

- (void)emit:(NSString *)t
{
    if (_log) _log(t);
}

- (void)next
{
    if (![_queue count]) { [self finish]; return; }
    TPRequest *r = [_queue objectAtIndex:0];
    [_queue removeObjectAtIndex:0];
    [self emit:[NSString stringWithFormat:@"%@\n  %@ %@\n", r.title, r.method, r.url]];
    TPConn *c = [[TPConn alloc] init];
    c.req = r;
    _current = c;
    __weak TPProbe *weakSelf = self;
    c.finish = ^{
        TPProbe *me = weakSelf;
        if (!me) return;
        [me report:r];
        [me->_done addObject:r];
        me->_current = nil;
        [me next];
    };
    [c start];
}

- (void)report:(TPRequest *)r
{
    NSMutableString *s = [NSMutableString string];
    if (r.gotChallenge) {
        [s appendFormat:@"  Certyfikat: %@ [%@]\n", r.trustState == 1 ? @"ZAUFANY" : @"NIEZAUFANY", TrustResultName(r.trustResult)];
        if ([r.chain length]) [s appendFormat:@"  Łańcuch: %@\n", r.chain];
    } else if (!r.errorText) {
        [s appendString:@"  Certyfikat: brak wyzwania\n"];
    }
    if (r.errorText) {
        [s appendFormat:@"  BŁĄD: %@\n", r.errorText];
    } else {
        [s appendFormat:@"  Odpowiedź: HTTP %ld, %lu B, %.0f ms (oczekiwano: %@)\n", (long)r.status, (unsigned long)r.bytes, r.ms, r.expect];
        if ([r.response length]) [s appendFormat:@"  Treść: %@\n", r.response];
    }
    [s appendString:@"\n"];
    [self emit:s];
}

- (void)finish
{
    int ok = 0, total = (int)[_done count];
    int msOk = 0, msTrusted = 0, msHandshakeFail = 0, ctrlOk = 0;
    for (TPRequest *r in _done) {
        BOOL answered = (r.errorText == nil && r.status > 0);
        NSRange msr1 = [r.url rangeOfString:@"microsoft"];
        BOOL isMS = msr1.location != NSNotFound;
        if (answered) ok++;
        if (isMS) {
            if (answered) msOk++;
            if (answered && r.trustState == 1) msTrusted++;
            if (!answered && !r.gotChallenge) msHandshakeFail++;
        } else if ([r.url rangeOfString:@"skype"].location == NSNotFound && answered) {
            ctrlOk++;
        }
    }
    NSMutableString *s = [NSMutableString stringWithFormat:@"== PODSUMOWANIE ==\nOdpowiedzi: %d z %d zapytań. Kontrole OK: %d z 2.\nMicrosoft: odpowiedzi %d z 3, zaufany certyfikat %d z 3.\n", ok, total, ctrlOk, msOk, msTrusted];
    if (ctrlOk == 0) {
        [s appendString:@"WNIOSEK: nawet strony kontrolne nie odpowiadają. Sprawdź Wi-Fi/internet i uruchom test jeszcze raz.\n"];
    } else if (msOk == 3 && msTrusted == 3) {
        [s appendString:@"WNIOSEK: DOBRZE. Telefon łączy się z Microsoftem i ufa jego certyfikatom. Można budować klienta Teams.\n"];
    } else if (msOk == 3) {
        [s appendString:@"WNIOSEK: Połączenie TLS działa, ale iOS 6 nie ufa certyfikatom Microsoftu (stary magazyn certyfikatów). Da się to obejść: dołożyć certyfikat główny na telefon albo przypiąć certyfikaty w aplikacji.\n"];
    } else if (msHandshakeFail > 0) {
        [s appendString:@"WNIOSEK: iOS 6 nie dogaduje się z serwerami Microsoftu już na etapie nawiązywania połączenia TLS (protokół albo szyfry). Potrzebny byłby pośrednik albo własna biblioteka TLS. Wyślij ten raport w całości.\n"];
    } else {
        [s appendString:@"WNIOSEK: wynik mieszany. Wyślij ten raport w całości, sprawdzę dokładnie.\n"];
    }
    [self emit:s];
    _running = NO;
    TPCrumbCleanExit();
    if (_final) _final();
}

@end
