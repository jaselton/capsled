#include <IOKit/hid/IOHIDManager.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
static void setAll(IOHIDManagerRef m, int on, const char *filter){
  CFSetRef devs=IOHIDManagerCopyDevices(m); if(!devs)return;
  CFIndex n=CFSetGetCount(devs); const void **d=malloc(n*sizeof(void*)); CFSetGetValues(devs,d);
  for(CFIndex i=0;i<n;i++){IOHIDDeviceRef dev=(IOHIDDeviceRef)d[i];
    char name[256]="?"; CFStringRef p=IOHIDDeviceGetProperty(dev,CFSTR(kIOHIDProductKey)); if(p)CFStringGetCString(p,name,256,kCFStringEncodingUTF8);
    if(filter && !strstr(name,filter))continue;
    CFArrayRef els=IOHIDDeviceCopyMatchingElements(dev,NULL,0); if(!els)continue;
    for(CFIndex j=0;j<CFArrayGetCount(els);j++){IOHIDElementRef e=(IOHIDElementRef)CFArrayGetValueAtIndex(els,j);
      if(IOHIDElementGetUsagePage(e)==kHIDPage_LEDs && IOHIDElementGetUsage(e)==kHIDUsage_LED_CapsLock){
        IOHIDValueRef v=IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault,e,0,on);
        IOReturn r=IOHIDDeviceSetValue(dev,e,v); CFRelease(v);
        if(getenv("CAPSLED_DEBUG"))fprintf(stderr,"%s -> %d (ret 0x%x)\n",name,on,r);}}
    CFRelease(els);}
  free(d); CFRelease(devs);}
int main(int argc,char**argv){
  int blinks=argc>1?atoi(argv[1]):5; const char*filter=argc>2?argv[2]:NULL;
  IOHIDManagerRef m=IOHIDManagerCreate(kCFAllocatorDefault,0);
  int page=kHIDPage_GenericDesktop,use=kHIDUsage_GD_Keyboard;
  CFNumberRef pn=CFNumberCreate(0,kCFNumberIntType,&page),un=CFNumberCreate(0,kCFNumberIntType,&use);
  const void*k[]={CFSTR(kIOHIDDeviceUsagePageKey),CFSTR(kIOHIDDeviceUsageKey)},*v[]={pn,un};
  CFDictionaryRef md=CFDictionaryCreate(0,k,v,2,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
  IOHIDManagerSetDeviceMatching(m,md); IOHIDManagerOpen(m,0);
  for(int i=0;i<blinks;i++){setAll(m,1,filter);usleep(400000);setAll(m,0,filter);usleep(400000);}
  if(argc>3)setAll(m,atoi(argv[3]),filter);
  return 0;}
