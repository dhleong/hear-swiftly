//
//  VoiceManager.swift
//  HearSwiftly
//
//  Created by Daniel Leong on 5/11/15.
//  Copyright (c) 2015 Dan Leong Apps. All rights reserved.
//

import Cocoa

struct Utterance {
    var voice: Voice
    var text: String
}

public class Voice {
    
    public let name: String
    
    internal var spec: VoiceSpec
    
    private var bridgeBlock: COpaquePointer?
    private var mgr: VoiceManager
    private var channel: SpeechChannel?
    
    private init(from spec: VoiceSpec, withName name: String, withMgr mgr: VoiceManager) {
        self.spec = spec
        self.name = name
        self.mgr = mgr
    }
    
    public func speak(message: String) {
        mgr.speak(Utterance(voice: self, text: message))
    }
    
    func dispose() {
        if let chan = channel {
            DisposeSpeechChannel(chan)
        }
        
        if let block = bridgeBlock {
            imp_removeBlock(block)
        }
    }
    
    /// Called by VoiceManager when it's our turn to talk
    func performSpeech(utterance: Utterance) {
        
        var nsText = utterance.text as NSString
        var text: CFString = nsText as CFString
        
        var channel = prepareChannel()
        SpeakCFString(channel, text, nil) // TODO options
    }
    
    private func prepareChannel() -> SpeechChannel {
        if let chan = channel {
            return chan
        }
        
        var bridge: @objc_block (SpeechChannel, Int) -> Void =
        { (chan, _) in
            self.mgr.onSpeechFinished(self)
        }
        bridgeBlock = imp_implementationWithBlock(unsafeBitCast(bridge, AnyObject.self))
        var callbackUPP = unsafeBitCast(bridgeBlock!, SpeechDoneUPP.self)
        
        // this hack discovered here: http://stackoverflow.com/a/17685620
        var callback = CFNumberCreate(nil, CFNumberType.LongType, &callbackUPP)
        
        var chan = SpeechChannel()
        NewSpeechChannel(&spec, &chan)
        SetSpeechProperty(chan, kSpeechSpeechDoneCallBack.takeRetainedValue(), callback)
        channel = chan
        return chan
    }
}

public class VoiceManager {
    
    public var voices: [Voice] = [];
    
    var curSpeechChannel: SpeechChannel? = SpeechChannel();
    
    private var queue: [Utterance] = []
    private var isSpeaking = false
    
    public init() {
        var numOfVoices: Int16 = 0;
        var theErr = CountVoices(&numOfVoices)
        if OSStatus(theErr) != noErr {
            NSLog("Error! \(theErr)")
            return;
        }
        
        var voiceSpec: VoiceSpec = VoiceSpec();
        for i in 1...numOfVoices {
            theErr = GetIndVoice(i, &voiceSpec)
            if OSStatus(theErr) != noErr {
                continue
            }
            
            var voiceDesc = VoiceDescription()
            theErr = GetVoiceDescription(&voiceSpec, &voiceDesc, sizeof(VoiceDescription))
            if OSStatus(theErr) != noErr {
                continue
            }
            
            // dance dance dance
            var cfsName = CFStringCreateWithPascalString(nil, &voiceDesc.name.0, kCFStringEncodingASCII)
            var nssName = cfsName as NSString
            var name: String = nssName as String
            
            voices.append(Voice(from: voiceSpec, withName: name, withMgr: self))
        }
    }

    public func dispose() {
        voices.map { $0.dispose() }
    }
    
    public func find(byName name: String) -> Voice? {
        return voices.filter({ $0.name == name }).first
    }

    func onSpeechFinished(previousVoice: Voice) {
        if !dequeueUtterance() {
            isSpeaking = false
        }
    }
    
    func speak(utterance: Utterance) {
        queue.append(utterance)
        
        if !isSpeaking {
            isSpeaking = true
            dequeueUtterance()
        }
    }
    
    private func dequeueUtterance() -> Bool {
        
        if queue.count == 0 {
            return false
        }
        
        let utterance = queue.removeAtIndex(0)
        utterance.voice.performSpeech(utterance)
        
        return true
    }
}