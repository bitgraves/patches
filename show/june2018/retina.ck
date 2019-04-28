// before the show, this was 3-shapefog.ck

/**
*  eventide:
*    mangled
*    98 hi -28 lo xnob (softclip) 30 yknob (out) -3.5db fxmix (wobble) 80 countour (midlvl) 55
*/

1 => int midiDeviceIndex;
1 => int enableOsc;

3 => int SLIDER_SILENCE_LENGTH_ID;
9 => int SLIDER_DELAY_MIX_ID;
13 => int SLIDER_PITCH_DESTROYER_ID;
14 => int SLIDER_MONITOR_ID;

// novation
/* 21 => SLIDER_SILENCE_LENGTH_ID;
23 => SLIDER_DUCK_DEPTH_ID;
24 => SLIDER_PITCH_DESTROYER_ID;
25 => SLIDER_MONITOR_ID;
*/

// not currently used
-1 => int SLIDER_DUCK_DEPTH_ID;
-1 => int SLIDER_ATTACK_SHARP_ID;
-1 => int SLIDER_BASE_ID;
-1 => int SLIDER_MULT_ID;
-1 => int SLIDER_GLITCH_PROB_ID;

OscSend oscTransmitter;

class ParamEvent extends Event {
    int index;
}
ParamEvent evtStop;
999 => int NOTE_IDX_ALL;
ParamEvent evtParam;
Event evtDuck;

Gain gWetGain;
Gain gChordsGain;
Dyno sidechain;

// stereo separator for higher voices
Gain gSeparator;
Pan2 separator => dac;
Delay gSeparatorDelay;
14::ms => gSeparatorDelay.delay;
gSeparator => separator.left;
gSeparator => gSeparatorDelay => separator.right;

Event evtDelayParam;

0.5 => float gBaseCoeff;
0.25 => float gMultCoeff;
1.0 => float gDuckDepth;
0 => float gGlitchProb;
0.7 => float gSilenceLength;
125.0 / 127.0 => float gPitchDestroyer;
1.0 => float gAttackSharpness;
1.0 => float gDelayMix;

fun void listenForMidi() {
    MidiIn min;
    MidiMsg msg;
    if (!min.open(midiDeviceIndex)) me.exit();
    while (true) {
        min => now;
        while (min.recv(msg)) {
            if (msg.data1 == 153) { // note on
                " " => string description;
                msg.data2 - 36 => int noteIndex;
                if (noteIndex == 0) {
                    NOTE_IDX_ALL => evtStop.index;
                    evtStop.broadcast();
                    "death" => description;
                } else if (noteIndex < 8) {
                    // fitting some chords onto the akai
                    doChordShortcut(noteIndex, 1);
                } else if (noteIndex == 11) {
                    0 => gMultCoeff;
                    evtParam.broadcast();
                    "faster on" => description;
                }
                logToOsc(1, 0, 0, description);
            } else if (msg.data1 == 137) { // note off
                msg.data2 - 36 => int noteIndex;
                if (noteIndex > 0 && noteIndex < 8) {
                    doChordShortcut(noteIndex, 0);
                } else if (noteIndex == 11) {
                    0.25 => gMultCoeff;
                    evtParam.broadcast();
                    logToOsc(1, 0, 0, "faster off");
                }
            } else if (msg.data1 == 144) { // key on
                msg.data2 - 36 => int noteIndex;
                ChordShape s;
                spork ~ s.run(adc.left, gChordsGain, noteIndex);
                <<< "start " + noteIndex >>>;
            } else if (msg.data1 == 128) { // key off
                msg.data2 - 36 => int noteIndex;
                noteIndex => evtStop.index;
                evtStop.broadcast();
                <<< "stop " + noteIndex >>>;
            } else if (msg.data1 == 176) { // knob twist
                (msg.data3 $ float) / 127.0 => float amount;
                " " => string description;
                if (msg.data2 == SLIDER_BASE_ID) {
                    amount => gBaseCoeff;
                    evtParam.broadcast();
                    "base " + amount => description;
                } else if (msg.data2 == SLIDER_SILENCE_LENGTH_ID) {
                    (1.0 - amount) * 0.7 => gSilenceLength;
                    evtParam.broadcast();
                    "silence " + gSilenceLength => description;
                } else if (msg.data2 == SLIDER_DELAY_MIX_ID) {
                    (1.0 - amount) => gDelayMix;
                    evtDelayParam.broadcast();
                    "delay mix " + gDelayMix => description;
                } else if (msg.data2 == SLIDER_ATTACK_SHARP_ID) {
                    amount => gAttackSharpness;
                    evtParam.broadcast();
                    "sharp " + amount => description;
                } else if (msg.data2 == SLIDER_GLITCH_PROB_ID) {
                    amount => gGlitchProb;
                    "glitch " + gGlitchProb => description;
                } else if (msg.data2 == SLIDER_DUCK_DEPTH_ID) {
                    amount => gDuckDepth;
                    evtParam.broadcast();
                    "not " + amount => description;
                } else if (msg.data2 == SLIDER_PITCH_DESTROYER_ID) {
                    // clamp midi input
                    Math.min(127, (msg.data3 + 2)) $ float / 127.0 => amount;
                    (1.0 - amount) => gPitchDestroyer;
                    evtParam.broadcast();
                    "destroy " + gPitchDestroyer => description;
                } else if (msg.data2 == SLIDER_MONITOR_ID) {
                    amount => gWetGain.gain;
                    "minitaur " + amount => description;
                } else if (msg.data2 == SLIDER_MULT_ID) {
                    amount => gMultCoeff;
                    evtParam.broadcast();
                    "mult " + amount => description;
                }
                if (description != " ") {
                    logToOsc(0, msg.data2, msg.data3, description);
                }
            }
        }
    }
}

fun void doChordShortcut(int padIndex, int isKeyOn) {
    [ 0 + 12, 1 + 12, 3 + 12 ] @=> int chordOffsets[];
    if (padIndex > 0 && padIndex < 4) {
        // three chords
        [ 0, 5, 7 ] @=> int chordShape[];
        for (0 => int noteIdx; noteIdx < chordShape.cap(); noteIdx++) {
            chordShape[noteIdx] + chordOffsets[padIndex - 1] => int noteVal;
            if (isKeyOn) {
                ChordShape s;
                spork ~ s.run(adc.left, gChordsGain, noteVal);
            } else {
                noteVal => evtStop.index;
                evtStop.broadcast();
            }
        }
    } else if (padIndex > 4 && padIndex < 8) {
        // high harmonic
        chordOffsets[padIndex - 5] + 12 => int noteVal;
        if (isKeyOn) {
            ChordShape s;
            spork ~ s.run(adc.left, gChordsGain, noteVal);
        } else {
            noteVal => evtStop.index;
            evtStop.broadcast();
        }
    }
    if (isKeyOn) {
        <<< "chord " + (padIndex - 1) >>>;
    } else {
        <<< "stop chord " + (padIndex - 1) >>>;
    }
}

class ModDelay {
    Echo _echo;
    PitShift _echoShift;
    
    fun void run(UGen in, UGen out) {
        1 => _echo.mix;
        0.5 => _echoShift.shift;
        1 => _echoShift.mix;
        0.8 => _echoShift.gain;
        0.25::second => _echo.delay;
        in => _echo => _echoShift => out;
        _echoShift => _echo;
        0 => int toggle;
        spork ~ _listenForParam();
        while (0.1::second => now) {
/*            if (toggle == 0) {
                1 => _echoShift.shift;
                toggle++;
            } else if (toggle == 1) {
                0.5 => _echoShift.shift;
                toggle++;
            } else if (toggle == 2) {
                0.25 => _echoShift.shift;
                0 => toggle;
            } */
        }
        _echoShift =< out;
    }

    fun void _listenForParam() {
        while (evtDelayParam => now) {
            gDelayMix => _echo.gain;
        }
    }
}

class Trembler {
    0 => float _baseCoeff;
    0 => float _multCoeff;
    ADSR _env;
    PitShift _shift;
    HPF _hpf;
    ModDelay _delay;
    
    fun void run(UGen in, UGen out) {
        _env.set(30::ms, 2::ms, 1, 30::ms);
        1 => _shift.mix;
        1 => _shift.shift;
        0.87 => _hpf.Q;
        1000 => _hpf.freq;
        
        in => _hpf =>  _shift => _env => out;
        spork ~ _delay.run(_env, out);
        
        1 => _env.keyOn;
        spork ~ _listenForParam();
        spork ~ _modulateSidechain();
        while (_getEnvDur()::second => now) {
            1 => _env.keyOff;
            (10 + (Math.randomf() * gSilenceLength * 500))::ms => now;
            3 => int numTries;
            do {
                if (Math.randomf() < 0.5) {
                    (_getEnvDur() * 0.5)::second => now;
                }
                evtDuck.broadcast();
                1 => _env.keyOn;
            } while (--numTries > 0);
        }
    }

    fun void _modulateSidechain() {
        while (1::samp => now) {
            _env.last() => sidechain.sideInput; // TODO: less hack
        }
    }

    fun float _getEnvDur() {
        // base: 0.25 sec - 0.05 sec
        0.2 - (_baseCoeff * 0.15) => float base;
        // mult: by 100%, 80%, ...
        Math.floor(_multCoeff * 5.0) + 1.0 => float multGroup;
        base * (multGroup / 5.0) => base;
        return base;
    }

    fun void _listenForParam() {
        while (evtParam => now) {
            gBaseCoeff => _baseCoeff;
            gMultCoeff => _multCoeff;
            gPitchDestroyer => _shift.shift;
            (30 - gAttackSharpness * 28)::ms => _env.attackTime;
            (30 - gDuckDepth * 25)::ms => _env.releaseTime;
        }
    }
}

class ChordShape {
    PitShift _p1;
    PitShift _p2;
    int _index;
    ADSR _env;
    
    fun void run(UGen in, UGen out, int index) {
        _env => out;
        0.8 => _env.gain;
        _env.set(1::second, 2::ms, 1, 8::second);

        index => _index;
        in => _p1 => _env;
        // in => _p2 => _env;

        1 => _p1.mix;
        1 => _p2.mix;

        spork ~ _adjustPitch();
        1 => _env.keyOn;
        while (evtStop => now) {
            if (evtStop.index == index || evtStop.index == NOTE_IDX_ALL) {
                1 => _env.keyOff;
                _env.releaseTime() => now;
                _env =< out;
                break;
            }
        }
    }

    fun void _adjustPitch() {
        int note1Index, note2Index;
        do {
            if (Math.randomf() < gGlitchProb * 0.5) {
                7 => note1Index;
                2 => note2Index;
            } else {
                12 => note1Index;
                7 => note2Index;
            }
            Math.pow(2.0, (_index + note1Index) / 12.0) => _p1.shift;
            Math.pow(2.0, (_index + note2Index) / 12.0) => _p2.shift;
        } while (evtDuck => now);
    }
}

fun void logToOsc(int type, int param, int value, string description) {
    if (enableOsc) {
        oscTransmitter.startMsg("/param", "i i i s");
        type => oscTransmitter.addInt;
        param => oscTransmitter.addInt;
        value => oscTransmitter.addInt;
        description => oscTransmitter.addString;
    }
    <<< description >>>;
    return;
}

if (enableOsc) {
    oscTransmitter.setHost("localhost", 4242);
}

adc.left => gWetGain => sidechain => dac;
sidechain.duck();
0.1 => sidechain.slopeAbove;
5::ms => sidechain.attackTime;
10::ms => sidechain.releaseTime;
0.01 => sidechain.thresh;

0 => gWetGain.gain;
0.87 => gChordsGain.gain;

Trembler t;
spork ~ t.run(gChordsGain, gSeparator);

spork ~ listenForMidi();
while (1::day => now);
