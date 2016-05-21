//
//  VoiceManager.swift
//  HearSwiftly
//
//  Created by Daniel Leong on 5/11/15.
//  Copyright (c) 2015 Dan Leong Apps. All rights reserved.
//
//   We don't use NSSpeechSynthesizer because its delegate's
//    didFinishSpeaking callback only fires when the feedback
//    window is shown, which is incredibly ridiculous
//

import Cocoa

struct Utterance {
    var voice: Voice
    var text: String
}

public class Voice {
    
    public let name: String
    public let lang: String?
    
    internal var spec: VoiceSpec
    
    private var bridgeBlock: COpaquePointer?
    private var mgr: VoiceManager
    private var channel: SpeechChannel?
    
    private init(from spec: VoiceSpec, withName name: String, withLang lang: String?, withMgr mgr: VoiceManager) {
        self.spec = spec
        self.name = name
        self.mgr = mgr
        self.lang = lang
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
        
        let nsText = utterance.text as NSString
        let text: CFString = nsText as CFString
        
        let channel = prepareChannel()
        SpeakCFString(channel, text, nil) // TODO options
    }
    
    private func prepareChannel() -> SpeechChannel {
        if let chan = channel {
            return chan
        }
        
        let bridge: @convention(block) (SpeechChannel, Int) -> Void =
        { (chan, _) in
            self.mgr.onSpeechFinished(self)
        }
        bridgeBlock = imp_implementationWithBlock(unsafeBitCast(bridge, AnyObject.self))
        var callbackUPP = unsafeBitCast(bridgeBlock!, SpeechDoneUPP.self)
        
        // this hack discovered here: http://stackoverflow.com/a/17685620
        let callback = CFNumberCreate(nil, CFNumberType.LongType, &callbackUPP)
        
        var chan:SpeechChannel = nil
        NewSpeechChannel(&spec, &chan)
        SetSpeechProperty(chan, kSpeechSpeechDoneCallBack, callback)
        channel = chan
        return chan
    }
}

public class VoiceManager {
    
    public var voices: [Voice] = [];
    private var defaultVoiceObj: Voice?
    
    var curSpeechChannel: SpeechChannel? = nil
    
    private var queue: [Utterance] = []
    private var isSpeaking = false
    
    public init() {
        var numOfVoices: Int16 = 0;
        var theErr = CountVoices(&numOfVoices)
        if OSStatus(theErr) != noErr {
            NSLog("Error! \(theErr)")
            return;
        }

        // NB: The Carbon API has some opaque Int describing the
        //  language and region, so we need the Cocoa API; the
        //  Cocoa API has crappy callback semantics, however, so
        //  we just use it for its information
        let nsVoices = NSSpeechSynthesizer.availableVoices()
        let nsDefaultVoice = NSSpeechSynthesizer.defaultVoice()
        var voiceLanguagesByName = [String:String]()
        var voiceIdsByName = [String:String]()

        for voice in nsVoices {
            
            let attributes = NSSpeechSynthesizer.attributesForVoice(voice)
            let name = attributes[NSVoiceName] as! String?
            let lang = attributes[NSVoiceLocaleIdentifier] as! String?
            if let key = name, val = lang {
                voiceLanguagesByName[key] = val
            }
            
            if let key = name {
                voiceIdsByName[key] = voice
            }
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
            let cfsName = CFStringCreateWithPascalString(nil, &voiceDesc.name.0, kCFStringEncodingASCII)
            let nssName = cfsName as NSString
            var name: String = nssName as String
            
            if let compactRange = name.rangeOfString(" Compact") {
                name.removeRange(compactRange)
            }
            
            let lang = voiceLanguagesByName[name]
            voices.append(Voice(from: voiceSpec,
                withName: name,
                withLang: lang,
                withMgr: self))
            
            if nsDefaultVoice == voiceIdsByName[name] {
                defaultVoiceObj = voices.last!
            }
        }
    }

    public func dispose() {
        voices.forEach { $0.dispose() }
    }
    
    public func defaultVoice() -> Voice {
        if let found = defaultVoiceObj {
            return found
        }
        
        return anyVoice()
    }
    
    /// Pick any random voice, possibly filtered by language.
    ///  The language is specified as a region string, eg: en_US
    public func anyVoice(forLang: String? = nil) -> Voice {
        var voices: [Voice]
        if let lang = forLang {
            voices = self.voices.filter { $0.lang == lang }
        } else {
            voices = self.voices // all
        }
        
        let randomIndex = arc4random_uniform(UInt32(voices.count))
        return voices[Int(randomIndex)]
    }
    
    public func find(byName name: String) -> Voice? {
        return voices.filter({ $0.name == name }).first
    }
    
    /// Convenience method to utter the `text` using the 
    ///  default voice
    public func speak(text: String) {
        defaultVoice().speak(text)
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