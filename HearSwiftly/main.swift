//
//  main.swift
//  HearSwiftly
//
//  Created by Daniel Leong on 5/11/15.
//  Copyright (c) 2015 Dan Leong Apps. All rights reserved.
//

import Foundation

var mgr = VoiceManager()
mgr.find(byName: "Alex")?.speak("Hello world!")
mgr.find(byName: "Vicki")?.speak("Queued speech!")

var voices = mgr.voices.map({ $0.name })
println("voices: \(voices)")
do {
    sleep(1)
} while (true)
