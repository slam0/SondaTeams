#import <Foundation/Foundation.h>

/* Prosta diagnostyka: zapisuje w Documents ostatni "krok" i treść nieobsłużonego wyjątku;
   przy następnym uruchomieniu aplikacja pokazuje to w okienku. */
void TPCrashInstall(void);
void TPCrumb(NSString *step);
void TPCrumbCleanExit(void);
NSString *TPTakeLastRunReport(void);
