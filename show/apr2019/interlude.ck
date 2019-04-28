// BEN next steps
/*
- be able to trigger a sequence
- be able to switch down to the G key (change base filter freq)
+ reuse RAM reasonably
--- can we just sample once and then loop at different impulse durations?
--- change pattern to D G C F A repeating
- randomize pan?
*/

1 => int midiDeviceIndex;
1 => int enableOsc;
0.85 => float gNormalizeGain;

3 => int SLIDER_FEEDBACK_RES_ID;
9 => int SLIDER_GRAINFREQ_ID;
12 => int SLIDER_DETUNE_ID;
13 => int SLIDER_SHUDDER_FREQ_ID;
14 => int SLIDER_MONITOR_ID;
15 => int SLIDER_GAIN_ID;
3 => int PAD_MONOTONIC_ID;
-1 => int SLIDER_RES_ID;
-1 => int SLIDER_FEEDBACK_ID;

// (293.66 * 2.0) * Math.pow(2.0, -7.0 / 12.0) => float baseGrainFreq;
440.0 * Math.pow(2.0, -26.0 / 12.0) => float baseGrainFreq;
baseGrainFreq => float baseFilterResFreq;
baseGrainFreq => float gCurrentGrainFreq;
baseFilterResFreq => float gCurrentFilterResFreq;
0.99 => float res; // start at min res
0 => float detuneRange;

2.0::second => dur gRelease; // start at medium release
0 => float duckProbability;
0.1::second => dur gShudderFreq;
0.998 => float gFeedback; // start at min feedback 
1 => float gHitGain;

// stereo separator for chuck hits
Gain gSeparator;
0.95 => gSeparator.gain;
Pan2 separator => dac;
Delay gSeparatorDelay;
5::ms => gSeparatorDelay.delay;
gSeparator => separator.left;
gSeparator => gSeparatorDelay => separator.right;

ADSR globalEnv => Dyno globalDyno => gSeparator;
// ADSR globalEnv => gSeparator;
// Dyno globalDyno;
globalDyno.limit();
0.85 => globalDyno.thresh;
gNormalizeGain => globalDyno.gain;
100::ms => globalDyno.releaseTime;
globalEnv.set(0.05::second, 0::second, 1.0, 0.015::second);
1 => globalEnv.keyOn;

adc.left => Gain monitorGain => dac;
1 => monitorGain.gain;

class ParamEvent extends Event {
    int paramId;
}
ParamEvent evtParam;
OscSend oscTransmitter;

// set initial state
getGrainFreq(1.0) => gCurrentGrainFreq;
SLIDER_GRAINFREQ_ID => evtParam.paramId;
evtParam.broadcast();

FilterGroup gFilterGroups[16];
// [ 0, 19, 15, 10, 5, 17, 12, 8 ] @=> int benMapping[];
[
    0, 5, 10, 15, 19, 8, 12, 17,
    0 + 12, 5 + 12, 10 + 12, 15 + 12, 19 + 12, 8 + 12, 12 + 12, 17 + 12
] @=> int benMapping[];
for (0 => int ii; ii < gFilterGroups.cap(); ii++) {
    gFilterGroups[ii].setUp(benMapping[ii], ii);
}

// midi control
fun void listenForMidi() {
    MidiIn min;
    MidiMsg msg;
    if (!min.open(midiDeviceIndex)) me.exit();
    while (true) {
        min => now;
        while (min.recv(msg)) {
            if (msg.data1 == 153) { // note on
                // spawn impulse
                msg.data2 - 36 => int noteIndex;
                akaiRange(msg.data3) => float vel;
                if (noteIndex < gFilterGroups.cap()) {
                    spork ~ gFilterGroups[noteIndex].run(vel);
                    <<< "Hit", noteIndex >>>;
                }
            } else if (msg.data1 == 137) { // note off
                msg.data2 - 36 => int noteIndex;
            } else if (msg.data1 == 176) { // knob twist
                " " => string description;
                if (msg.data2 == SLIDER_GRAINFREQ_ID) {
                    ((msg.data3$float + 1.0) / 128.0) => float grainFreqScalar;
                    getGrainFreq(grainFreqScalar) => gCurrentGrainFreq;
                    SLIDER_GRAINFREQ_ID => evtParam.paramId;
                    evtParam.broadcast();
                    gCurrentGrainFreq + " Hz" => description;
                } else if (msg.data2 == SLIDER_DETUNE_ID) {
                    ((msg.data3$float + 1.0) / 128.0) => float amount;
                    amount * 0.08 => detuneRange;
                    "Detune range: " + amount => description;
                    <<< description >>>;
                } else if (msg.data2 == SLIDER_FEEDBACK_ID) {
                    ((msg.data3$float + 1.0) / 128.0) => float feedbackScalar;
                    0.998 + (0.0019 * feedbackScalar) => gFeedback; // keep in sync w combined
                    SLIDER_FEEDBACK_ID => evtParam.paramId;
                    evtParam.broadcast();
                    feedbackScalar + " feedback" => description;
                } else if (msg.data2 == SLIDER_SHUDDER_FREQ_ID) {
                    (msg.data3$float / 127.0) => float amount;
                    (100 - (90 * amount))::ms => gShudderFreq;
                    "Rhythm " + amount => description;
                    <<< description >>>;
                } else if (msg.data2 == SLIDER_RES_ID) {
                    (msg.data3$float / 128.0) => float amount;
                    0.99 + (amount * 0.0093) => res; // keep in sync w combined
                    SLIDER_RES_ID => evtParam.paramId;
                    evtParam.broadcast();
                    <<< "Rez:", amount >>>;
                } else if (msg.data2 == SLIDER_FEEDBACK_RES_ID) {
                    ((msg.data3$float + 1.0) / 128.0) => float feedbackScalar;
                    (msg.data3$float / 128.0) => float amount;
                    0.998 + (0.0019 * feedbackScalar) => gFeedback; // keep in sync w combined
                    0.99 + (amount * 0.0093) => res; // keep in sync w combined
                    SLIDER_FEEDBACK_RES_ID => evtParam.paramId;
                    evtParam.broadcast();
                    feedbackScalar + " feedback/rez" => description;
                    <<< description >>>;
                } else if (msg.data2 == SLIDER_GAIN_ID) {
                    (msg.data3$float / 127.0) => float amount;
                    amount => gHitGain;
                    <<< "pads gain", amount >>>;
                    amount * 100 + "%" => description;
                } else if (msg.data2 == SLIDER_MONITOR_ID) {
                    (msg.data3$float / 127.0) => float amount;
                    amount * 0.9 * gNormalizeGain => monitorGain.gain;
                    <<< "Monitor", amount >>>;
                    amount * 100 + "%" => description;
                }
                if (enableOsc) {
                    logToOsc(0, msg.data2, msg.data3, description);
                }
            }
        }
    }
}

fun float getGrainFreq(float grainFreqScalar) {
    baseGrainFreq => float lo;
    baseGrainFreq * Math.pow(2.0, 7.0 / 12.0) => float hi;
    return hi - ((hi - lo) * grainFreqScalar);
}

fun float akaiRange(int midiVal) {
    37 + (Math.max(37, midiVal) - 37) $ int => int clampedVal;
    return clampedVal $ float / 128.0;
}

class rezFilter {
    BiQuad lp;
    DelayA _delay;
    DelayA out;
    Gain _feedback;
    0 => int isStopped;
    0 => int _noteIndex;
    1 => float _detune;
    1::ms => dur _impDuration;

    Dyno _dyno;

    fun void setUp(int noteIndex) {
        noteIndex => _noteIndex;
        _dyno.limit();
        0.4 => _dyno.thresh;
        1::ms => _dyno.attackTime;
        1::second => _dyno.releaseTime;

        (1.0 / baseGrainFreq)::second => _delay.max;
        (1.0 / baseGrainFreq)::second => _delay.delay;

        adc.left => _delay => lp => _dyno;
        // 0.999 => _delay.gain; // TODO: BEN
        _delay => _feedback => _delay;
        0.9999 => _feedback.gain;
        1::ms => out.delay;
        
        run(adc.left, 0, 1.0);
        _dyno => out;
        _updateFreqs();
        spork ~ _listenForParam();
        // lol
        // TODO: BEN
        for (0 => int ii; ii < 5; ii++) {
            adc.left => _delay;
        }
    }
    
    fun void run(UGen _unusedIn, float detune, float vel) {
        0 => isStopped;
        0.00008 * gHitGain * vel => lp.gain;

        detune => _detune;
        Math.fabs(1 + (30.0 * detune))::ms => out.delay;
        _updateFreqs();

        // 0.998 => _feedback.gain;
        
        // in => _delay;
        // (_delay.delay()) * 8.0 => now;
        // in =< _delay;
        // 1.0 => _feedback.gain;
    }

    fun void stop() {
        1 => isStopped;
    }

    fun void _listenForParam() {
        while (evtParam => now) {
            if (evtParam.paramId == SLIDER_GRAINFREQ_ID || evtParam.paramId == SLIDER_RES_ID || evtParam.paramId == SLIDER_FEEDBACK_RES_ID) {
                _updateFreqs();
            }
            if (evtParam.paramId == SLIDER_FEEDBACK_ID || evtParam.paramId == SLIDER_FEEDBACK_RES_ID) {
                gFeedback => _feedback.gain;
            }
        }
    }

    fun void _updateFreqs() {
        res => lp.prad;
        getFreq(gCurrentFilterResFreq, lp.pfreq()) => lp.pfreq;
        1 => lp.eqzs;
        getFreq(gCurrentGrainFreq * (1.0 + _detune), gCurrentGrainFreq) => float _grainFreq;
        (1.0 / _grainFreq)::second => _impDuration;
        if (_impDuration != _delay.delay()) {
            _impDuration => _delay.delay;
        }
    }

    fun float getFreq(float baseFreq, float prevFreq) {
        return baseFreq * Math.pow(2, (_noteIndex)$float / 12.0) * (1.0 + _detune);
    }
}

class FilterGroup {
    0 => int _noteIndex;
    0 => int _padIndex;
    rezFilter _rfs[3];
    ADSR _env;

    fun void setUp(int noteIndex, int padIndex) {
        noteIndex => _noteIndex;
        for (0 => int ii; ii < 3; ii++) {
            _rfs[ii].setUp(noteIndex);
            _rfs[ii].out => _env;
        }
        _env => globalEnv;
        _env.set(3::ms, 0.05::second, 0.1, gRelease);
    }

    fun void run(float vel) {
        // ramp down vel for lower notes
        if (_padIndex < 8) {
            0.01 * (15.0 - _noteIndex) -=> vel;
        }
        for (0 => int ii; ii < 3; ii++) {
            0 => float detune;
            if (ii > 0) {
                Std.rand2f(-detuneRange, detuneRange) => detune;
            }
            _rfs[ii].run(adc.left, detune, vel * (1.0 - ii$float * 0.1));
        }

        1 => _env.keyOn;
        _env.attackTime() => now;
        1 => _env.keyOff;
        _env.releaseTime() => now;
    }
}

fun void maybeDuck() {
    while (gShudderFreq => now) {
        1 => globalEnv.keyOff;
        globalEnv.releaseTime() => now;
        1 => globalEnv.keyOn;
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

spork ~ listenForMidi();
spork ~ maybeDuck();
while (1::day => now);    
