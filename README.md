HearSwiftly [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
===========

*Hear what your computer has to say!*

## What?

HearSwiftly provides more convenient Speech Synthesis in Swift, hiding all the 
CoreFramework cruft and providing the interface you always wanted

### Usage example

```swift
var mgr = VoiceManager()
mgr.find(byName: "Alex")?.speak("Would you like fries with that?")
mgr.find(byName: "Vicki")?.speak("Why, yes I would!")
```

The underlying framework will either override previous utterances or drop the 
new ones; With HearSwiftly, however, utterances are queued up and spoken in
order. The queueing is done per-`VoiceManager`, so you can use multiple 
`VoiceManager` instances to overlap voices, if so desired.
