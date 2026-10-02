#ifndef MINI_KEYBOARD_USB_H
#define MINI_KEYBOARD_USB_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Returns 1 when the 1189:8890 configuration interface is present, 0 when it
/// is not present, and a negative value when probing failed.
int32_t MKUSBProbe(char *message, size_t messageCapacity);

/// Opens interface 1 and endpoint 0x02, but sends no data. Returns 0 on success.
int32_t MKUSBCheckAccess(char *message, size_t messageCapacity);

/// Reads the HID report descriptor from configuration interface 1.
int32_t MKUSBGetReportDescriptor(
    uint8_t *descriptor,
    size_t descriptorCapacity,
    size_t *descriptorLength,
    char *message,
    size_t messageCapacity
);

/// Attempts a standard HID GET_REPORT request on configuration interface 1.
/// This is read-only. `reportType` is 1=input, 2=output, or 3=feature.
int32_t MKUSBGetReport(
    uint8_t reportType,
    uint8_t reportID,
    uint8_t *report,
    size_t reportCapacity,
    size_t *reportLength,
    char *message,
    size_t messageCapacity
);

/// Sends `reportCount` contiguous, `reportLength`-byte interrupt-OUT reports.
/// Returns 0 on success. The caller must pass fully framed HID reports.
int32_t MKUSBSendReports(
    const uint8_t *reports,
    size_t reportCount,
    size_t reportLength,
    char *message,
    size_t messageCapacity
);

#ifdef __cplusplus
}
#endif

#endif
