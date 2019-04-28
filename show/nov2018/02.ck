// knob 1 at 146
// todo: make shudder not random
// todo: make attack tweakable

1 => int midiDeviceIndex;
1 => int enableOsc;
0.85 => float gNormalizeGain;

3 => int SLIDER_GRAINFREQ_ID;
9 => int SLIDER_PAD_OFFSET_ID;
12 => int SLIDER_DETUNE_ID;
13 => int SLIDER_BASE_FREQ_BEND_ID; // TODO: remap
15 => int SLIDER_SHUDDER_FREQ_ID;
14 => int SLIDER_MONITOR_ID;
20 => int SLIDER_RELEASE_ID;
21 => int SLIDER_RES_ID;
3 => int PAD_MONOTONIC_ID;

293.66 / 4.0 => float baseGrainFreq;
baseGrainFreq => float grainFreq;
0.999 => float res; // start at max rez
0 => float detuneRange;
293.66 => float baseFilterResFreq;
0 => float gFilterBend;
0 => float gFilterRand;
8.0::second => dur release; // start at medium release
0 => float duckProbability;
0 => int padOffset;
0 => int isMonotonic; // if true, spawned pads can't be reduced in harmonic
0.1::second => dur gShudderFreq;

// stereo separator for chuck hits
Gain gSeparator;
Pan2 separator => dac;
Delay gSeparatorDelay;
5::ms => gSeparatorDelay.delay;
gSeparator => separator.left;
gSeparator => gSeparatorDelay => separator.right;

ADSR globalEnv => Dyno globalDyno => gSeparator;
globalDyno.limit();
gNormalizeGain => globalDyno.gain;
100::ms => globalDyno.releaseTime;
globalEnv.set(0.05::second, 0::second, 1.0, 0.015::second);
1 => globalEnv.keyOn;

adc.left => Gain monitorGain => dac;
0 => monitorGain.gain;

class ParamEvent extends Event {
    int paramId;
}
ParamEvent evtParam;

OscSend oscTransmitter;

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
                if (noteIndex == PAD_MONOTONIC_ID) {
                    1 => isMonotonic;
                    <<< "Enable monotonic" >>>;
                } else {
                    akaiRange(msg.data3) => float vel;
                    FilterGroup fg;
                    spork ~ fg.run(noteIndex, vel);
                    <<< "Spawn", noteIndex, "+", padOffset >>>;
                }
            } else if (msg.data1 == 137) { // note off
                msg.data2 - 36 => int noteIndex;
                if (noteIndex == PAD_MONOTONIC_ID) {
                    0 => isMonotonic;
                    <<< "Disable monotonic" >>>;
                }
            } else if (msg.data1 == 176) { // knob twist
                " " => string description;
                if (msg.data2 == SLIDER_GRAINFREQ_ID) {
                    ((msg.data3$float + 1.0) / 128.0) => float grainFreqScalar;
                    getGrainFreq(grainFreqScalar) => grainFreq;
                    <<< "Grain freq:", grainFreq >>>;
                    grainFreq + " Hz" => description;
                } else if (msg.data2 == SLIDER_PAD_OFFSET_ID) {
                    (msg.data3$float / 127.0) => float amount;
                    4 + Math.floor(amount * 20.0) $ int => int padOffsetMagnitude;
                    padOffsetMagnitude * -1 => padOffset;
                    SLIDER_PAD_OFFSET_ID => evtParam.paramId;
                    evtParam.broadcast();
                    <<< "Pad offset", padOffset >>>;
                    padOffset + "" => description;
                } else if (msg.data2 == SLIDER_DETUNE_ID) {
                    ((msg.data3$float + 1.0) / 128.0) => float amount;
                    amount * 0.08 => detuneRange;
                    "Detune range: " + amount => description;
                    <<< description >>>;
                } else if (msg.data2 == SLIDER_BASE_FREQ_BEND_ID) { // TODO: remap
                    (msg.data3$float / 127.0) => float amount;
                    amount => gFilterBend;
                    SLIDER_BASE_FREQ_BEND_ID => evtParam.paramId;
                    evtParam.broadcast();
                    "Filter creep: " + amount => description;
                    <<< description >>>;
                } else if (msg.data2 == SLIDER_SHUDDER_FREQ_ID) {
                    (msg.data3$float / 127.0) => float amount;
                    (100 - (90 * amount))::ms => gShudderFreq;
                    "Rhythm " + amount => description;
                    <<< description >>>;
                } else if (msg.data2 == SLIDER_RELEASE_ID) {
                    (msg.data3$float / 127.0) => float amount;
                    (5.0 + (amount * 5.0))::second => release;
                    <<< "Release:", (release / second) >>>;
                } else if (msg.data2 == SLIDER_RES_ID) {
                    (msg.data3$float / 128.0) => float amount;
                    0.996 + (amount * 0.003) => res;
                    <<< "Rez:", amount >>>;
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
    Math.floor(grainFreqScalar * 8.0) $ int => int grainFreqIndex;
    0 => int noteIndex;
    for (0 => int ii; ii < grainFreqIndex; ii++) {
        if (ii % 2 == 0) {
            5 +=> noteIndex;
        } else {
            7 +=> noteIndex;
        }
    }
    return baseGrainFreq * Math.pow(2.0, noteIndex / 12.0);
}

fun float akaiRange(int midiVal) {
    37 + (Math.max(37, midiVal) - 37) $ int => int clampedVal;
    return clampedVal $ float / 128.0;
}

class rezFilter {
    BiQuad lp;
    Delay out;
    0 => int _isStopped;
    0 => int _noteIndex;
    1 => float _detune;
    0 => int _isMonotonic;
    
    fun void setUpAndListen(int noteIndex, float vel, float detune, int isMonotonic) {
        noteIndex => _noteIndex;
        detune => _detune;
        isMonotonic => _isMonotonic;
        
        // 0.1 => float gainCoeff;
        0.015 => float gainCoeff;
        gainCoeff * vel => lp.gain;
        res => lp.prad;
        1 => lp.eqzs;
        getFilterResFreq(1) => lp.pfreq;
        Math.fabs(30.0 * detune)::ms => out.delay;
        lp => out;
        while (evtParam => now) {
            if (evtParam.paramId == SLIDER_PAD_OFFSET_ID || evtParam.paramId == SLIDER_BASE_FREQ_BEND_ID) {
                getFilterResFreq(lp.pfreq()) => lp.pfreq;
            }
        }
    }

    fun float getFilterResFreq(float prevFreq) {
        baseFilterResFreq * Math.pow(2 + gFilterBend + gFilterRand, (_noteIndex + padOffset)$float / 12.0) * (1.0 + _detune) => float result;
        if (_isMonotonic && result < prevFreq) {
            // one way street here
            return prevFreq;
        } else {
            return result;
        }
    }
}

class FilterGroup {
    baseGrainFreq => float _grainFreq;
    0 => int _isStopped;

    fun void run(int noteIndex, float vel) {
        // Impulse i => _lp => dac;
        ADSR env;
        adc.left => LiSa buf;

        // ramp down vel for lower notes
        float lastDetune;
        if (noteIndex < 15) {
            0.008 * (15.0 - noteIndex) -=> vel;
        }
        for (0 => int ii; ii < 3; ii++) {
            0 => float detune;
            if (ii > 0) {
                Std.rand2f(-detuneRange, detuneRange) => detune;
            }
            rezFilter rf;
            spork ~ rf.setUpAndListen(noteIndex, vel * (1.0 - ii$float * 0.1), detune, isMonotonic);
            // a => rf.lp => env => globalEnv;
            buf => rf.lp;
            rf.out => env => globalEnv;
            detune => lastDetune;
        }
        
        grainFreq * (1.0 + lastDetune) => _grainFreq;
        (1.0 / _grainFreq)::second => dur impDuration;

        dur finalRelease;
        if (isMonotonic) {
            release + 2::second => finalRelease;
        } else {
            release => finalRelease;
        }
        env.set(3::second, 0.2::second, 0.9, finalRelease);
        impDuration => buf.duration;
        buf.recRamp(impDuration * 0.25);
        buf.record(1);
        impDuration => now;
        buf.record(0);
        

        // adc.left.last() => i.next;
        buf.play(1);
        1 => env.keyOn;
        env.attackTime() => now;
        1 => env.keyOff;
        env.releaseTime() => now;
        1 => _isStopped;
        env =< globalEnv;
    }
}

fun void maybeDuck() {
    while (gShudderFreq => now) {
        // if (Math.randomf() < duckProbability * 0.6) {
            1 => globalEnv.keyOff;
            globalEnv.releaseTime() => now;
            Math.randomf() * 0.1 => gFilterRand;
            SLIDER_BASE_FREQ_BEND_ID => evtParam.paramId;
            evtParam.broadcast();
            1 => globalEnv.keyOn;
        // }
    }
}

fun void randomOffset() {
    (Math.floor(Math.randomf() * 24.0) * -1) $ int => padOffset;
    SLIDER_PAD_OFFSET_ID => evtParam.paramId;
    evtParam.broadcast();
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
