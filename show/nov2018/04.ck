
// knob: initial range up-down
// knob: spread up-down
// knob: bloom mode linearup, lineardown, random

1 => int midiDeviceIndex;
1 => int enableOsc;

0 => int BLOOM_MODE_LINEAR;
1 => int BLOOM_MODE_RANDOM;
12 => int MAX_SPREAD;

3 => int SLIDER_CLOUD_POSITION_ID;
9 => int SLIDER_CLOUD_SPREAD_ID;
12 => int SLIDER_CLOUD_SIZE_ID;
13 => int SLIDER_STEP_SIZE_ID;
14 => int SLIDER_DRY_ID;
15 => int SLIDER_BITCRUSH_WET_ID;

16 => int SLIDER_CLOUD_LENGTH_ID;

OscSend oscTransmitter;

0 => int gInitialCloudIndex;
1 => int gIntervalSpread;
9 => int gCloudSize;
1.0 => float gCloudLength;
200 => int gStepSizeMs;
0 => float gBitCrushWet;
BLOOM_MODE_RANDOM => int gBloomMode;

Gain gGainOut;
adc.left => Gain gGainDry;
0 => gGainDry.gain;
0.85 => gGainOut.gain;
Event gEvtBitCrushParam;

Gain gSeparator;
Pan2 separator => dac;
Delay gSeparatorDelay;
14::ms => gSeparatorDelay.delay;
gSeparator => separator.left;
gSeparator => gSeparatorDelay => separator.right;

// midi control
fun void listenForMidi() {
    MidiIn min;
    MidiMsg msg;
    if (!min.open(midiDeviceIndex)) me.exit();
    while (true) {
        min => now;
        while (min.recv(msg)) {
            if (msg.data1 == 153) { // note on
                msg.data2 - 36 => int noteIndex;
                akaiRange(msg.data3) => float noteVel;
                VoiceCloud vc;
                spork ~ vc.run(adc.left, gGainOut, noteIndex, noteVel);
                logToOsc(1, 0, 0, "swarm " + noteIndex);
            } else if (msg.data1 == 137) { // note off
                msg.data2 - 36 => int noteIndex;
            } else if (msg.data1 == 176) { // knob twist
                " " => string description;
                msg.data3 $ float / 127.0 => float amount;
                if (msg.data2 == SLIDER_CLOUD_POSITION_ID) {
                    (amount * 36.0) $ int => gInitialCloudIndex;
                    "Cloud index " + gInitialCloudIndex => description;
                } else if (msg.data2 == SLIDER_CLOUD_SPREAD_ID) {
                    1 + (amount * MAX_SPREAD) $ int => gIntervalSpread;
                    "Cloud spread" + gIntervalSpread => description;
                } else if (msg.data2 == SLIDER_CLOUD_SIZE_ID) {
                    9 + (amount * 6.0) $ int => gCloudSize;
                    "Cloud size" + gCloudSize => description;
                } else if (msg.data2 == SLIDER_DRY_ID) {
                    amount => gGainDry.gain;
                    "Monitor " + amount => description;
                } else if (msg.data2 == SLIDER_CLOUD_LENGTH_ID) {
                    0.3 + (0.7 * amount) => gCloudLength;
                    "Cloud length" + gCloudLength => description;
                } else if (msg.data2 == SLIDER_STEP_SIZE_ID) {
                    amount * 0.2 => amount;
                    (10.0 + (190.0 * amount)) $ int => gStepSizeMs;
                    "Step length " + amount => description;
                } else if (msg.data2 == SLIDER_BITCRUSH_WET_ID) {
                    amount => gBitCrushWet;
                    gEvtBitCrushParam.broadcast();
                    "Bitcrush " + gBitCrushWet => description;
                }
                if (description != " ") {
                    logToOsc(0, msg.data2, msg.data3, description);
                    <<< description >>>;
                }
            }
        }
    }
}

fun float akaiRange(int midiVal) {
    37 + (Math.max(37, midiVal) - 37) $ int => int clampedVal;
    return clampedVal $ float / 128.0;
}

class VoiceCloud {
    fun void run(UGen in, UGen out, int accentIndex, float accentVel) {
        0::ms => dur maxLifespan;
        gCloudSize => int cloudSize;
        gInitialCloudIndex => int index;
        // Bitcrusher b => out;
        // 8 => b.bits;
        // 16 => b.downsampleFactor;
        // Chorus f => b => out;
        for (0 => int ii; ii < cloudSize; ii++) {
            Voice v;
            (index == accentIndex || index == accentIndex + 4) => int isAccent;
            (isAccent) ? accentVel : Math.min(accentVel, 0.3) => float velocity;
            velocity * 0.9 => velocity;
            spork ~ v.run(in, out, velocity, index, ii, cloudSize);
            this._incrementIndex(index, ii, gIntervalSpread) => index;
            // await spork
            1::ms => now;
            v.getLifespan() => dur lifespan;
            if (lifespan > maxLifespan) {
                lifespan => maxLifespan;
            }
        }
        maxLifespan => now;
    }

    fun int _incrementIndex(int noteIndex, int indexInCloud, int spread) {
        // return noteIndex + Math.random2(1, spread);
        (MAX_SPREAD + 1) - spread => int divisor;
        Math.ceil(indexInCloud $ float / divisor) $ int => int reducedIndex;
        return noteIndex + Math.random2(1, reducedIndex);
    }
}

[ 0, 2, 3, 5, 7, 9, 10 ] @=> int dorIntervals[];
class Voice {
    PitShift _p;
    ADSR _env;
    int _index;
    dur _lifespan;
    
    fun void run(UGen in, UGen out, float vel, int noteIndex, int indexInCloud, int cloudSize) {
        noteIndex => _index;
        in => _p => _env => out;
        if (gBloomMode == BLOOM_MODE_LINEAR) {
            _env.set(((0.05 + indexInCloud) * gCloudLength)::second, 1::ms, 0.99, ((1 + indexInCloud) * gCloudLength)::second);
        } else {
            _env.set((Math.random2f(0.05, cloudSize * 0.3) * gCloudLength)::second, 1::ms, 0.99, (Math.random2(3, cloudSize * 2) * gCloudLength)::second);
        }
        if (vel > 0.5) {
            Math.random2f(0.05, 0.15)::second => _env.attackTime;
        }
        vel => _p.gain;
        _env.attackTime() + _env.releaseTime() => _lifespan;
        1 => _p.mix;
        // spork ~ this._maybeChangePitch();
        this._getShift(_index) => _p.shift;
        1 => _env.keyOn;
        _env.attackTime() => now;
        1 => _env.keyOff;
        _env.releaseTime() => now;
        in =< _p;
        _env =< out;
    }

    fun dur getLifespan() {
        return _lifespan;
    }

    fun float _getShift(int index) {
        index / dorIntervals.cap() => int octave;
        (octave * 12) + dorIntervals[index % dorIntervals.cap()] => int scaleIndex;
        return Math.pow(2.0, (scaleIndex $ float) / 12.0);
    }

    fun float _maybeChangePitch() {
        while ((Math.random2(1, 5) * 100)::ms => now) {
            _index + Math.random2(-2, 2) => _index;
            if (_index < 0) 0 => _index;
            _getShift(_index) => _p.shift;
        }
    }
}

class TextureDrone {
    PitShift _p;
    ADSR _env;
    LPF _lpf;
    
    fun void run(UGen in, UGen out) {
        in => _env => out;
        0.25 => _p.shift;
        1 => _p.mix;
        2500.0 => _lpf.freq;
        0.9 => _lpf.Q;
        _env.set(1::ms, 5::ms, 0.4, 5::ms);
        while (true) {
            1 => _env.keyOn;
            _env.attackTime() + _env.decayTime() => now;
            (Math.random2(1, 3) * gStepSizeMs)::ms => now;
            1 => _env.keyOff;
            _env.releaseTime() => now;
            (Math.random2(1, 3) * gStepSizeMs)::ms => now;
        }
    }
}

class BitCrushMaybe {
    Bitcrusher _bc;
    Gain _gWet;
    Gain _gDry;
    
    fun void run(UGen in, UGen out) {
        1 => _gDry.gain;
        0 => _gWet.gain;
        8 => _bc.bits;
        16 => _bc.downsampleFactor;
        in => _bc => _gWet => out;
        in => _gDry => out;
        while (gEvtBitCrushParam => now) {
            gBitCrushWet => _gWet.gain;
            1.0 - gBitCrushWet => _gDry.gain;
        }
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

// VoiceCloud vc;
// vc.run(adc.left, dac, 0, 0.85);

spork ~ listenForMidi();
TextureDrone td;
spork ~ td.run(gGainDry, dac);
BitCrushMaybe bc;
spork ~ bc.run(gGainOut, gSeparator);

while (1::day => now);
