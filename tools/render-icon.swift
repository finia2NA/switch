#!/usr/bin/env swift
// Render the Switch app icon to a 1024×1024 PNG.
// Run: swift tools/render-icon.swift > tools/icon-1024.png

import AppKit

let size = NSSize(width: 1024, height: 1024)
let img = NSImage(size: size)
img.lockFocus()
NSColor(calibratedRed: 0.18, green: 0.10, blue: 0.20, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 200, yRadius: 200).fill()
NSColor.white.setFill()
NSRect(x: 256, y: 256, width: 512, height: 384).fill()
img.unlockFocus()

let tiff = img.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
FileHandle.standardOutput.write(png)
