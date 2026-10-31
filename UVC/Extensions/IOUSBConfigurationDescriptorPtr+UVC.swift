//
//  IOUSBConfigurationDescriptorPtr+UVC.swift
//  CameraController
//
//  Created by Itay Brenner on 7/20/20.
//  Copyright © 2020 Itaysoft. All rights reserved.
//

import Foundation
import IOKit

extension IOUSBConfigurationDescriptorPtr {
    func proccessDescriptor() -> UVCDescriptor {
        var processingUnitID = -1
        var cameraTerminalID = -1
        var interfaceID = -1

        let remaining = self.pointee.wTotalLength - UInt16(self.pointee.bLength)
        var pointer = UnsafeMutablePointer<UInt8>(OpaquePointer(self))
        pointer = pointer.advanced(by: Int(self.pointee.bLength))

        browseDescriptor(remaining, pointer, &processingUnitID, &cameraTerminalID, &interfaceID)

        return UVCDescriptor(processingUnitID: processingUnitID,
                             cameraTerminalID: cameraTerminalID,
                             interfaceID: interfaceID)
    }

    private func browseDescriptor(_ memory: UInt16, _ pointer: UnsafeMutablePointer<UInt8>,
                                  _ processingUnitID: inout Int,
                                  _ cameraTerminalID: inout Int,
                                  _ interfaceID: inout Int) {
        // Linear state-machine walker over every descriptor in the config block.
        //
        // The previous implementation assumed a fixed descriptor ordering (VC Header
        // immediately after VC Interface descriptor, terminals/units immediately after
        // VC Header, no other interfaces in between). That assumption holds on some
        // cameras but not others — e.g. the Logitech C922 interleaves descriptors in
        // a way that caused the walker to exit before finding the Processing Unit /
        // Camera Terminal IDs, leaving the Basic/Advanced tabs empty.
        //
        // This version walks the entire config block once and tracks whether we're
        // currently inside the Video Control interface (between its standard Interface
        // descriptor and the next standard Interface descriptor that isn't video-control).
        // While inside, it picks up Input Terminal (subtype 0x02) and Processing Unit
        // (subtype 0x05) IDs from class-specific (0x24) descriptors wherever they appear.
        var remaining = Int(memory)
        var currentPointer = pointer
        var insideVideoControl = false

        while remaining > 0 {
            let header = InterfaceDescriptorPointer(OpaquePointer(currentPointer))
            let bLength = Int(header.pointee.bLength)
            let bType = Int(header.pointee.bDescriptorType)

            // Guard against malformed descriptors (bLength == 0 → infinite loop;
            // bLength > remaining → out-of-bounds read on the next iteration).
            guard bLength > 0, bLength <= remaining else { break }

            if bType == kUSBInterfaceDesc {
                // Standard interface descriptor — entering a new interface block.
                let intDesc = UnsafeMutablePointer<IOUSBInterfaceDescriptor>(OpaquePointer(header))
                let isVideoControl = Int(intDesc.pointee.bInterfaceClass) == Int(UVCConstants.classVideo)
                    && Int(intDesc.pointee.bInterfaceSubClass) == Int(UVCConstants.subclassVideoControl)

                if isVideoControl {
                    insideVideoControl = true
                    interfaceID = Int(intDesc.pointee.bInterfaceNumber)
                } else {
                    // Any other interface (audio, HID, video-streaming, etc.) ends the
                    // video-control block. We stay walking in case there are multiple
                    // VC interfaces (rare, but cheap to support).
                    insideVideoControl = false
                }
            } else if insideVideoControl && bType == UVCConstants.descriptorTypeInterface {
                // Class-specific (CS_INTERFACE) descriptor within Video Control.
                // Read its subtype and pick up Input Terminal / Processing Unit IDs.
                if let unitType = UVCConstants.DescriptorSubtype(rawValue: header.pointee.bDescriptorSubType) {
                    switch unitType {
                    case .inputTerminal:
                        let ctPointer = CameraTerminalDescriptorPointer(OpaquePointer(currentPointer))
                        cameraTerminalID = Int(ctPointer.pointee.bTerminalID)
                    case .processingUnit:
                        let puPointer = ProcessingUnitDescriptorPointer(OpaquePointer(currentPointer))
                        processingUnitID = Int(puPointer.pointee.bUnitID)
                    case .selectorUnit, .extensionUnit:
                        break
                    }
                }

                // Early-exit once we have everything (matches previous WB7022 fix).
                if interfaceID != -1 && processingUnitID != -1 && cameraTerminalID != -1 {
                    return
                }
            }

            remaining -= bLength
            currentPointer = currentPointer.advanced(by: bLength)
        }
    }

}
