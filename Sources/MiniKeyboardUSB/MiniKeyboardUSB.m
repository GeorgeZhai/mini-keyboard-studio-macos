#import "MiniKeyboardUSB.h"

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/USB.h>
#import <IOKit/usb/USBSpec.h>
#import <IOUSBHost/IOUSBHost.h>
#import <unistd.h>

static const uint16_t kMiniKeyboardVendorID = 0x1189;
static const uint16_t kMiniKeyboardProductID = 0x8890;
static const NSUInteger kMiniKeyboardInterfaceNumber = 1;
static const NSUInteger kMiniKeyboardOutputEndpoint = 0x02;

static void MKCopyMessage(char *destination, size_t capacity, NSString *message) {
    if (destination == NULL || capacity == 0) {
        return;
    }
    const char *utf8 = message.UTF8String ?: "Unknown USB error";
    snprintf(destination, capacity, "%s", utf8);
}

static io_service_t MKCopyConfigurationService(void) {
    CFMutableDictionaryRef matching = IOServiceMatching("IOUSBHostInterface");
    if (matching == NULL) {
        return IO_OBJECT_NULL;
    }

    io_iterator_t iterator = IO_OBJECT_NULL;
    kern_return_t result = IOServiceGetMatchingServices(
        kIOMainPortDefault, matching, &iterator);
    if (result != KERN_SUCCESS) {
        return IO_OBJECT_NULL;
    }

    io_service_t matchedService = IO_OBJECT_NULL;
    io_service_t candidate = IO_OBJECT_NULL;
    while ((candidate = IOIteratorNext(iterator)) != IO_OBJECT_NULL) {
        CFTypeRef vendorValue = IORegistryEntryCreateCFProperty(
            candidate, CFSTR("idVendor"), kCFAllocatorDefault, 0);
        CFTypeRef productValue = IORegistryEntryCreateCFProperty(
            candidate, CFSTR("idProduct"), kCFAllocatorDefault, 0);
        CFTypeRef interfaceValue = IORegistryEntryCreateCFProperty(
            candidate, CFSTR("bInterfaceNumber"), kCFAllocatorDefault, 0);

        int vendor = 0;
        int product = 0;
        int interfaceNumber = -1;
        if (vendorValue != NULL && CFGetTypeID(vendorValue) == CFNumberGetTypeID()) {
            CFNumberGetValue(vendorValue, kCFNumberIntType, &vendor);
        }
        if (productValue != NULL && CFGetTypeID(productValue) == CFNumberGetTypeID()) {
            CFNumberGetValue(productValue, kCFNumberIntType, &product);
        }
        if (interfaceValue != NULL && CFGetTypeID(interfaceValue) == CFNumberGetTypeID()) {
            CFNumberGetValue(interfaceValue, kCFNumberIntType, &interfaceNumber);
        }

        if (vendorValue != NULL) CFRelease(vendorValue);
        if (productValue != NULL) CFRelease(productValue);
        if (interfaceValue != NULL) CFRelease(interfaceValue);

        if (vendor == kMiniKeyboardVendorID &&
            product == kMiniKeyboardProductID &&
            interfaceNumber == (int)kMiniKeyboardInterfaceNumber) {
            matchedService = candidate;
            break;
        }
        IOObjectRelease(candidate);
    }
    IOObjectRelease(iterator);
    return matchedService;
}

int32_t MKUSBProbe(char *message, size_t messageCapacity) {
    io_service_t service = MKCopyConfigurationService();
    if (service == IO_OBJECT_NULL) {
        MKCopyMessage(message, messageCapacity,
                      @"No 1189:8890 configuration interface is connected.");
        return 0;
    }

    IOObjectRelease(service);
    MKCopyMessage(message, messageCapacity,
                  @"USB 1189:8890 found on configuration interface 1.");
    return 1;
}

static IOUSBHostInterface *MKOpenConfigurationInterface(
    IOUSBHostPipe **outputPipe,
    NSString **failureMessage
) {
    io_service_t service = MKCopyConfigurationService();
    if (service == IO_OBJECT_NULL) {
        if (failureMessage != NULL) {
            *failureMessage = @"The mini keyboard is not connected.";
        }
        return nil;
    }

    NSError *openError = nil;
    IOUSBHostInterface *interface = [[IOUSBHostInterface alloc]
        initWithIOService:service
                  options:IOUSBHostObjectInitOptionsNone
                    queue:nil
                    error:&openError
          interestHandler:nil];
    IOObjectRelease(service);

    if (interface == nil) {
        if (failureMessage != NULL) {
            *failureMessage = [NSString stringWithFormat:
                @"Could not open configuration interface 1: %@",
                openError.localizedDescription ?: @"unknown error"];
        }
        return nil;
    }

    NSError *pipeError = nil;
    IOUSBHostPipe *pipe = [interface copyPipeWithAddress:kMiniKeyboardOutputEndpoint
                                                   error:&pipeError];
    if (pipe == nil) {
        if (failureMessage != NULL) {
            *failureMessage = [NSString stringWithFormat:
                @"Could not open output endpoint 0x02: %@",
                pipeError.localizedDescription ?: @"unknown error"];
        }
        [interface destroy];
        return nil;
    }

    if (outputPipe != NULL) {
        *outputPipe = pipe;
    }
    return interface;
}

int32_t MKUSBCheckAccess(char *message, size_t messageCapacity) {
    NSString *failure = nil;
    IOUSBHostPipe *pipe = nil;
    IOUSBHostInterface *interface = MKOpenConfigurationInterface(&pipe, &failure);
    if (interface == nil) {
        MKCopyMessage(message, messageCapacity, failure ?: @"USB access failed.");
        return -1;
    }

    pipe = nil;
    [interface destroy];
    MKCopyMessage(message, messageCapacity,
                  @"Configuration interface 1 and endpoint 0x02 are accessible.");
    return 0;
}

int32_t MKUSBGetReportDescriptor(
    uint8_t *descriptor,
    size_t descriptorCapacity,
    size_t *descriptorLength,
    char *message,
    size_t messageCapacity
) {
    if (descriptor == NULL || descriptorCapacity == 0 || descriptorLength == NULL) {
        MKCopyMessage(message, messageCapacity, @"No report-descriptor buffer was supplied.");
        return -2;
    }

    NSString *failure = nil;
    IOUSBHostPipe *pipe = nil;
    IOUSBHostInterface *interface = MKOpenConfigurationInterface(&pipe, &failure);
    if (interface == nil) {
        MKCopyMessage(message, messageCapacity, failure ?: @"USB access failed.");
        return -1;
    }

    NSUInteger requestedLength = MIN(descriptorCapacity, UINT16_MAX);
    IOUSBDeviceRequest request = {
        .bmRequestType = USBmakebmRequestType(kUSBIn, kUSBStandard, kUSBInterface),
        .bRequest = kUSBRqGetDescriptor,
        .wValue = HostToUSBWord((kUSBReportDesc << 8) | 0),
        .wIndex = HostToUSBWord(kMiniKeyboardInterfaceNumber),
        .wLength = HostToUSBWord((uint16_t)requestedLength)
    };
    NSMutableData *data = [NSMutableData dataWithLength:requestedLength];
    NSUInteger transferred = 0;
    NSError *readError = nil;
    BOOL success = [interface sendDeviceRequest:request
                                           data:data
                               bytesTransferred:&transferred
                              completionTimeout:1.0
                                          error:&readError];
    if (!success) {
        MKCopyMessage(message, messageCapacity,
                      [NSString stringWithFormat:@"Could not read report descriptor: %@",
                          readError.localizedDescription ?: @"unknown error"]);
        pipe = nil;
        [interface destroy];
        return -3;
    }

    memcpy(descriptor, data.bytes, transferred);
    *descriptorLength = transferred;
    pipe = nil;
    [interface destroy];
    MKCopyMessage(message, messageCapacity,
                  [NSString stringWithFormat:@"Read %lu descriptor bytes.",
                      (unsigned long)transferred]);
    return 0;
}

int32_t MKUSBGetReport(
    uint8_t reportType,
    uint8_t reportID,
    uint8_t *report,
    size_t reportCapacity,
    size_t *reportLength,
    char *message,
    size_t messageCapacity
) {
    if (reportType < kHIDRtInputReport || reportType > kHIDRtFeatureReport ||
        report == NULL || reportCapacity == 0 || reportLength == NULL) {
        MKCopyMessage(message, messageCapacity, @"Invalid HID GET_REPORT arguments.");
        return -2;
    }

    NSString *failure = nil;
    IOUSBHostPipe *pipe = nil;
    IOUSBHostInterface *interface = MKOpenConfigurationInterface(&pipe, &failure);
    if (interface == nil) {
        MKCopyMessage(message, messageCapacity, failure ?: @"USB access failed.");
        return -1;
    }

    NSUInteger requestedLength = MIN(reportCapacity, UINT16_MAX);
    IOUSBDeviceRequest request = {
        .bmRequestType = USBmakebmRequestType(kUSBIn, kUSBClass, kUSBInterface),
        .bRequest = kHIDRqGetReport,
        .wValue = HostToUSBWord((((uint16_t)reportType) << 8) | reportID),
        .wIndex = HostToUSBWord(kMiniKeyboardInterfaceNumber),
        .wLength = HostToUSBWord((uint16_t)requestedLength)
    };
    NSMutableData *data = [NSMutableData dataWithLength:requestedLength];
    NSUInteger transferred = 0;
    NSError *readError = nil;
    BOOL success = [interface sendDeviceRequest:request
                                           data:data
                               bytesTransferred:&transferred
                              completionTimeout:1.0
                                          error:&readError];
    if (!success) {
        MKCopyMessage(message, messageCapacity,
                      [NSString stringWithFormat:@"HID GET_REPORT type %u failed: %@",
                          reportType,
                          readError.localizedDescription ?: @"not supported"]);
        pipe = nil;
        [interface destroy];
        return -3;
    }

    memcpy(report, data.bytes, transferred);
    *reportLength = transferred;
    pipe = nil;
    [interface destroy];
    MKCopyMessage(message, messageCapacity,
                  [NSString stringWithFormat:@"Read %lu bytes from HID report type %u.",
                      (unsigned long)transferred, reportType]);
    return 0;
}

int32_t MKUSBSendReports(
    const uint8_t *reports,
    size_t reportCount,
    size_t reportLength,
    char *message,
    size_t messageCapacity
) {
    if (reports == NULL || reportCount == 0 || reportLength == 0) {
        MKCopyMessage(message, messageCapacity, @"No HID reports were supplied.");
        return -2;
    }

    NSString *failure = nil;
    IOUSBHostPipe *pipe = nil;
    IOUSBHostInterface *interface = MKOpenConfigurationInterface(&pipe, &failure);
    if (interface == nil || pipe == nil) {
        MKCopyMessage(message, messageCapacity, failure ?: @"USB access failed.");
        return -1;
    }

    for (size_t index = 0; index < reportCount; index++) {
        const uint8_t *start = reports + (index * reportLength);
        NSMutableData *payload = [NSMutableData dataWithBytes:start length:reportLength];
        NSUInteger transferred = 0;
        NSError *writeError = nil;
        BOOL success = [pipe sendIORequestWithData:payload
                                  bytesTransferred:&transferred
                                 completionTimeout:0
                                             error:&writeError];
        if (!success || transferred != reportLength) {
            NSString *detail = writeError.localizedDescription ?: @"short USB write";
            MKCopyMessage(message, messageCapacity,
                          [NSString stringWithFormat:
                              @"Report %zu of %zu failed (%lu/%zu bytes): %@",
                              index + 1, reportCount,
                              (unsigned long)transferred, reportLength, detail]);
            pipe = nil;
            [interface destroy];
            return -3;
        }

        // The original configurator writes commands sequentially. A small gap
        // prevents inexpensive controller firmware from dropping a report.
        usleep(8000);
    }

    pipe = nil;
    [interface destroy];
    MKCopyMessage(message, messageCapacity,
                  [NSString stringWithFormat:@"Sent %zu configuration reports.", reportCount]);
    return 0;
}
