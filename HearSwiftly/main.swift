//
//  main.swift
//  HearSwiftly
//
//  Created by Daniel Leong on 5/11/15.
//  Copyright (c) 2015 Dan Leong Apps. All rights reserved.
//

import Cocoa
import Foundation

import HearSwiftly

var mgr = VoiceManager()
mgr.find(byName: "Alex")?.speak("Hello world!")
mgr.anyVoice("en_US").speak("Queued speech!")
mgr.speak("Awesome!")

var voices = mgr.voices.map({ "name=\($0.name); lang=\($0.lang)\n" })
print("voices: \(voices)")
repeat {
    sleep(1)
} while (true)
